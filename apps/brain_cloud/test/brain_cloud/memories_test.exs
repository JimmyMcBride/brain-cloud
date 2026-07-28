defmodule BrainCloud.MemoriesTest do
  use BrainCloud.DataCase, async: true

  alias BrainCloud.Accounts.AuditEvent
  alias BrainCloud.Memories
  alias BrainCloud.Memories.Memory
  alias BrainCloud.Memories.MemoryRevision
  alias BrainCloud.Projects
  alias BrainCloud.Repo

  setup do
    identity = identity_fixture()
    {:ok, project} = Projects.create_project(%{name: "Research"}, identity.auth_context)
    %{identity: identity, project: project}
  end

  test "creates one immutable revision transactionally and retrieves it", %{
    identity: identity,
    project: project
  } do
    attrs = %{
      title: "  Phoenix Notes  ",
      content: "# Durable\nPhoenix keeps exact Markdown.",
      content_type: "text/markdown"
    }

    assert {:ok, memory} = Memories.create_memory(project.id, attrs, identity.auth_context)
    assert [revision] = memory.revisions
    assert revision.revision_number == 1
    assert revision.title == "Phoenix Notes"
    assert revision.content == attrs.content
    assert revision.content_type == "text/markdown"
    assert revision.actor_id == identity.user.id

    assert revision.content_hash ==
             Base.encode16(:crypto.hash(:sha256, attrs.content), case: :lower)

    assert stored =
             Memories.get_memory(project.id, memory.id, identity.organization.id)

    assert [stored_revision] = stored.revisions
    assert stored_revision.id == revision.id

    event = Repo.get_by!(AuditEvent, action: "memory.create", resource_id: memory.id)
    assert event.organization_id == identity.organization.id
    assert event.actor_user_id == identity.user.id
    assert event.api_token_id == identity.token.id
    assert event.metadata == %{}
  end

  test "rejects invalid revision content and content type", %{
    identity: identity,
    project: project
  } do
    memory_count = Repo.aggregate(Memory, :count, :id)
    audit_count = Repo.aggregate(AuditEvent, :count, :id)

    assert {:error, changeset} =
             Memories.create_memory(
               project.id,
               %{title: "Title", content: "", content_type: "text/markdown"},
               identity.auth_context
             )

    assert "must be between 1 byte and 1 MiB" in errors_on(changeset).content
    assert Repo.aggregate(Memory, :count, :id) == memory_count

    assert {:error, changeset} =
             Memories.create_memory(
               project.id,
               %{title: "Title", content: "Body", content_type: "text/plain"},
               identity.auth_context
             )

    assert "is invalid" in errors_on(changeset).content_type
    assert Repo.aggregate(Memory, :count, :id) == memory_count
    assert Repo.aggregate(AuditEvent, :count, :id) == audit_count
  end

  test "enforces title and byte-size limits", %{identity: identity, project: project} do
    assert {:error, changeset} =
             Memories.create_memory(
               project.id,
               %{
                 title: String.duplicate("a", 201),
                 content: "Body",
                 content_type: "text/markdown"
               },
               identity.auth_context
             )

    assert "should be at most 200 character(s)" in errors_on(changeset).title

    assert {:error, changeset} =
             Memories.create_memory(
               project.id,
               %{
                 title: "Title",
                 content: String.duplicate("a", 1_048_577),
                 content_type: "text/markdown"
               },
               identity.auth_context
             )

    assert "must be between 1 byte and 1 MiB" in errors_on(changeset).content
  end

  test "enforces foreign and revision uniqueness constraints", %{
    identity: identity,
    project: project
  } do
    invalid_project_id = Ecto.UUID.generate()

    assert {:error, changeset} =
             %Memory{}
             |> Memory.changeset(%{project_id: invalid_project_id})
             |> Repo.insert()

    assert "does not exist" in errors_on(changeset).project_id

    {:ok, memory} =
      Memories.create_memory(
        project.id,
        %{title: "Title", content: "Body", content_type: "text/markdown"},
        identity.auth_context
      )

    assert {:error, changeset} =
             %MemoryRevision{}
             |> MemoryRevision.changeset(%{
               memory_id: memory.id,
               revision_number: 1,
               title: "Duplicate",
               content: "Body",
               content_type: "text/markdown",
               actor_id: identity.user.id
             })
             |> Repo.insert()

    assert "has already been taken" in errors_on(changeset).revision_number
  end

  test "rejects missing projects without inserting a memory", %{identity: identity} do
    assert {:error, :project_not_found} =
             Memories.create_memory(
               Ecto.UUID.generate(),
               %{title: "Title", content: "Body", content_type: "text/markdown"},
               identity.auth_context
             )
  end

  test "scopes retrieval and keyword search by project and organization", %{
    identity: identity,
    project: project
  } do
    {:ok, other_project} =
      Projects.create_project(%{name: "Other"}, identity.auth_context)

    {:ok, memory} =
      Memories.create_memory(
        project.id,
        %{
          title: "Phoenix Search",
          content: "# Durable cloud memory",
          content_type: "text/markdown"
        },
        identity.auth_context
      )

    assert Memories.get_memory(other_project.id, memory.id, identity.organization.id) == nil

    assert {:ok, [result]} =
             Memories.search(project.id, "PHOENIX", identity.organization.id)

    assert result.memory_id == memory.id
    assert result.title == "Phoenix Search"
    assert result.excerpt == "Durable cloud memory"
    assert is_float(result.rank)

    assert {:ok, []} =
             Memories.search(other_project.id, "phoenix", identity.organization.id)

    assert {:ok, []} = Memories.search(project.id, "missing", identity.organization.id)

    other_identity = identity_fixture()

    assert Memories.get_memory(project.id, memory.id, other_identity.organization.id) == nil

    assert {:error, :project_not_found} =
             Memories.search(project.id, "phoenix", other_identity.organization.id)
  end

  test "validates search queries and missing projects", %{identity: identity, project: project} do
    assert {:error, {:validation_failed, %{q: [_message]}}} =
             Memories.search(project.id, " ", identity.organization.id)

    assert {:error, {:validation_failed, %{q: [_message]}}} =
             Memories.search(
               project.id,
               String.duplicate("a", 257),
               identity.organization.id
             )

    assert {:error, :project_not_found} =
             Memories.search(Ecto.UUID.generate(), "memory", identity.organization.id)
  end

  test "stores the generated search vector behind a GIN index" do
    assert {:ok, %{rows: [[index_definition]]}} =
             Ecto.Adapters.SQL.query(
               Repo,
               """
               SELECT indexdef
               FROM pg_indexes
               WHERE schemaname = current_schema()
                 AND tablename = 'memory_revisions'
                 AND indexname = 'memory_revisions_search_vector_index'
               """,
               []
             )

    assert index_definition =~ "USING gin"
    assert index_definition =~ "search_vector"
  end
end
