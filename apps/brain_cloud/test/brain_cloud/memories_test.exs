defmodule BrainCloud.MemoriesTest do
  use BrainCloud.DataCase, async: true

  alias BrainCloud.Memories
  alias BrainCloud.Memories.Memory
  alias BrainCloud.Memories.MemoryRevision
  alias BrainCloud.Projects
  alias BrainCloud.Repo

  @actor_id "00000000-0000-0000-0000-000000000001"

  setup do
    {:ok, project} = Projects.create_project(%{name: "Research"}, @actor_id)
    %{project: project}
  end

  test "creates one immutable revision transactionally and retrieves it", %{project: project} do
    attrs = %{
      title: "  Phoenix Notes  ",
      content: "# Durable\nPhoenix keeps exact Markdown.",
      content_type: "text/markdown"
    }

    assert {:ok, memory} = Memories.create_memory(project.id, attrs, @actor_id)
    assert [revision] = memory.revisions
    assert revision.revision_number == 1
    assert revision.title == "Phoenix Notes"
    assert revision.content == attrs.content
    assert revision.content_type == "text/markdown"
    assert revision.actor_id == @actor_id

    assert revision.content_hash ==
             Base.encode16(:crypto.hash(:sha256, attrs.content), case: :lower)

    assert stored = Memories.get_memory(project.id, memory.id)
    assert [stored_revision] = stored.revisions
    assert stored_revision.id == revision.id
  end

  test "rejects invalid revision content and content type", %{project: project} do
    memory_count = Repo.aggregate(Memory, :count)

    assert {:error, changeset} =
             Memories.create_memory(
               project.id,
               %{title: "Title", content: "", content_type: "text/markdown"},
               @actor_id
             )

    assert "must be between 1 byte and 1 MiB" in errors_on(changeset).content
    assert Repo.aggregate(Memory, :count) == memory_count

    assert {:error, changeset} =
             Memories.create_memory(
               project.id,
               %{title: "Title", content: "Body", content_type: "text/plain"},
               @actor_id
             )

    assert "is invalid" in errors_on(changeset).content_type
    assert Repo.aggregate(Memory, :count) == memory_count
  end

  test "enforces title and byte-size limits", %{project: project} do
    assert {:error, changeset} =
             Memories.create_memory(
               project.id,
               %{
                 title: String.duplicate("a", 201),
                 content: "Body",
                 content_type: "text/markdown"
               },
               @actor_id
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
               @actor_id
             )

    assert "must be between 1 byte and 1 MiB" in errors_on(changeset).content
  end

  test "enforces foreign and revision uniqueness constraints", %{project: project} do
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
        @actor_id
      )

    assert {:error, changeset} =
             %MemoryRevision{}
             |> MemoryRevision.changeset(%{
               memory_id: memory.id,
               revision_number: 1,
               title: "Duplicate",
               content: "Body",
               content_type: "text/markdown",
               actor_id: @actor_id
             })
             |> Repo.insert()

    assert "has already been taken" in errors_on(changeset).revision_number
  end

  test "rejects missing projects without inserting a memory" do
    assert {:error, :project_not_found} =
             Memories.create_memory(
               Ecto.UUID.generate(),
               %{title: "Title", content: "Body", content_type: "text/markdown"},
               @actor_id
             )
  end

  test "scopes retrieval and keyword search by project", %{project: project} do
    {:ok, other_project} = Projects.create_project(%{name: "Other"}, @actor_id)

    {:ok, memory} =
      Memories.create_memory(
        project.id,
        %{
          title: "Phoenix Search",
          content: "# Durable cloud memory",
          content_type: "text/markdown"
        },
        @actor_id
      )

    assert Memories.get_memory(other_project.id, memory.id) == nil

    assert {:ok, [result]} = Memories.search(project.id, "PHOENIX")
    assert result.memory_id == memory.id
    assert result.title == "Phoenix Search"
    assert result.excerpt == "Durable cloud memory"
    assert is_float(result.rank)

    assert {:ok, []} = Memories.search(other_project.id, "phoenix")
    assert {:ok, []} = Memories.search(project.id, "missing")
  end

  test "validates search queries and missing projects", %{project: project} do
    assert {:error, {:validation_failed, %{q: [_message]}}} = Memories.search(project.id, " ")

    assert {:error, {:validation_failed, %{q: [_message]}}} =
             Memories.search(project.id, String.duplicate("a", 257))

    assert {:error, :project_not_found} = Memories.search(Ecto.UUID.generate(), "memory")
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
