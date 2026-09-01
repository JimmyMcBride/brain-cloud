defmodule BrainCloud.MemoriesTest do
  use BrainCloud.DataCase, async: true

  alias BrainCloud.Accounts.AuditEvent
  alias BrainCloud.Accounts
  alias BrainCloud.Agents
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
    assert revision.actor_user_id == identity.user.id
    assert is_nil(revision.actor_agent_id)
    assert MemoryRevision.actor_type(revision) == "human"
    assert MemoryRevision.actor_id(revision) == identity.user.id

    assert revision.content_hash ==
             Base.encode16(:crypto.hash(:sha256, attrs.content), case: :lower)

    assert {:ok, stored} =
             Memories.get_memory(project.id, memory.id, identity.auth_context)

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
               actor_user_id: identity.user.id
             })
             |> Repo.insert()

    assert "has already been taken" in errors_on(changeset).revision_number
  end

  test "requires exactly one revision actor and enforces agent tenant provenance", %{
    identity: identity,
    project: project
  } do
    memory = Repo.insert!(Memory.changeset(%Memory{}, %{project_id: project.id}))

    {:ok, agent} = Agents.create_agent(%{name: "Same tenant"}, identity.auth_context)

    base = %{
      memory_id: memory.id,
      revision_number: 1,
      title: "Actor check",
      content: "Body",
      content_type: "text/markdown"
    }

    assert %{actor_user_id: ["exactly one actor is required"]} =
             %MemoryRevision{}
             |> MemoryRevision.changeset(base)
             |> errors_on()

    assert %{actor_user_id: ["exactly one actor is required"]} =
             %MemoryRevision{}
             |> MemoryRevision.changeset(
               Map.merge(base, %{
                 actor_user_id: identity.user.id,
                 actor_agent_id: agent.id
               })
             )
             |> errors_on()

    other_identity = identity_fixture()
    {:ok, other_agent} = Agents.create_agent(%{name: "Other tenant"}, other_identity.auth_context)

    assert {:error, changeset} =
             %MemoryRevision{}
             |> MemoryRevision.changeset(Map.put(base, :actor_agent_id, other_agent.id))
             |> Repo.insert()

    assert "is invalid" in errors_on(changeset).actor_agent_id
  end

  test "agent editor creates memory with authentic revision and audit provenance", %{
    identity: identity,
    project: project
  } do
    {:ok, agent} = Agents.create_agent(%{name: "Writer"}, identity.auth_context)

    {:ok, _grant} =
      Projects.put_agent_project_access_grant(
        project.id,
        agent.id,
        "editor",
        identity.auth_context
      )

    {:ok, _token, raw} =
      Agents.create_agent_token(
        agent.id,
        %{name: "Write", scopes: ["memory.write"]},
        identity.auth_context
      )

    {:ok, agent_auth} = Accounts.authenticate(raw)

    assert {:ok, memory} =
             Memories.create_memory(
               project.id,
               %{title: "Agent note", content: "Automated", content_type: "text/markdown"},
               agent_auth
             )

    assert [revision] = memory.revisions
    assert is_nil(revision.actor_user_id)
    assert revision.actor_agent_id == agent.id
    assert MemoryRevision.actor_type(revision) == "agent"
    assert MemoryRevision.actor_id(revision) == agent.id

    event = Repo.get_by!(AuditEvent, action: "memory.create", resource_id: memory.id)
    assert is_nil(event.actor_user_id)
    assert event.actor_agent_id == agent.id
    assert event.api_token_id == agent_auth.api_token_id
  end

  test "agent write requires both write scope and editor access", %{
    identity: identity,
    project: project
  } do
    {:ok, agent} = Agents.create_agent(%{name: "Bounded writer"}, identity.auth_context)

    {:ok, _reader_grant} =
      Projects.put_agent_project_access_grant(
        project.id,
        agent.id,
        "reader",
        identity.auth_context
      )

    {:ok, _token, raw} =
      Agents.create_agent_token(
        agent.id,
        %{name: "Write", scopes: ["memory.write"]},
        identity.auth_context
      )

    {:ok, agent_auth} = Accounts.authenticate(raw)

    {:ok, _read_token, read_raw} =
      Agents.create_agent_token(
        agent.id,
        %{name: "Read", scopes: ["memory.read"]},
        identity.auth_context
      )

    {:ok, read_auth} = Accounts.authenticate(read_raw)

    assert {:error, :forbidden} =
             Memories.create_memory(
               project.id,
               %{title: "No scope", content: "Denied", content_type: "text/markdown"},
               read_auth
             )

    assert {:error, :project_not_found} =
             Memories.create_memory(
               project.id,
               %{title: "Denied", content: "Denied", content_type: "text/markdown"},
               agent_auth
             )

    {:ok, _editor_grant} =
      Projects.put_agent_project_access_grant(
        project.id,
        agent.id,
        "editor",
        identity.auth_context
      )

    assert {:ok, _memory} =
             Memories.create_memory(
               project.id,
               %{title: "Allowed", content: "Allowed", content_type: "text/markdown"},
               agent_auth
             )
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

    assert {:error, :memory_not_found} =
             Memories.get_memory(other_project.id, memory.id, identity.auth_context)

    assert {:ok, [result]} =
             Memories.search(project.id, "PHOENIX", identity.auth_context)

    assert result.memory_id == memory.id
    assert result.title == "Phoenix Search"
    assert result.excerpt == "Durable cloud memory"
    assert is_float(result.rank)

    assert {:ok, []} =
             Memories.search(other_project.id, "phoenix", identity.auth_context)

    assert {:ok, []} = Memories.search(project.id, "missing", identity.auth_context)

    other_identity = identity_fixture()

    assert {:error, :project_not_found} =
             Memories.get_memory(project.id, memory.id, other_identity.auth_context)

    assert {:error, :project_not_found} =
             Memories.search(project.id, "phoenix", other_identity.auth_context)
  end

  test "validates search queries and missing projects", %{identity: identity, project: project} do
    assert {:error, {:validation_failed, %{q: [_message]}}} =
             Memories.search(project.id, " ", identity.auth_context)

    assert {:error, {:validation_failed, %{q: [_message]}}} =
             Memories.search(
               project.id,
               String.duplicate("a", 257),
               identity.auth_context
             )

    assert {:error, :project_not_found} =
             Memories.search(Ecto.UUID.generate(), "memory", identity.auth_context)
  end

  test "enforces reader and editor project access before memory queries", %{
    identity: identity,
    project: project
  } do
    suffix = Ecto.UUID.generate()

    {:ok, membership} =
      Accounts.create_organization_membership(identity.auth_context, %{
        email: "memory-member-#{suffix}@example.test",
        display_name: "Memory Member",
        role: "member"
      })

    {:ok, _token, raw_token} =
      Accounts.create_membership_api_token(identity.auth_context, membership.id, %{
        name: "Memory access",
        scopes: ["memory.read", "memory.write", "search.keyword"]
      })

    {:ok, member_auth} = Accounts.authenticate(raw_token)

    assert {:ok, _grant} =
             Projects.put_project_access_grant(
               project.id,
               membership.id,
               "reader",
               identity.auth_context
             )

    assert {:error, :project_not_found} =
             Memories.create_memory(
               project.id,
               %{title: "Denied", content: "Denied", content_type: "text/markdown"},
               member_auth
             )

    assert {:ok, []} = Memories.search(project.id, "anything", member_auth)

    assert {:ok, _grant} =
             Projects.put_project_access_grant(
               project.id,
               membership.id,
               "editor",
               identity.auth_context
             )

    assert {:ok, memory} =
             Memories.create_memory(
               project.id,
               %{title: "Allowed", content: "Allowed", content_type: "text/markdown"},
               member_auth
             )

    assert {:ok, _memory} = Memories.get_memory(project.id, memory.id, member_auth)

    assert :ok =
             Projects.delete_project_access_grant(
               project.id,
               membership.id,
               identity.auth_context
             )

    assert {:error, :project_not_found} =
             Memories.get_memory(project.id, memory.id, member_auth)

    assert {:error, :project_not_found} = Memories.search(project.id, "allowed", member_auth)
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
