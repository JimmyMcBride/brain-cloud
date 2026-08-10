defmodule BrainCloud.ProvenanceConstraintsTest do
  use BrainCloud.DataCase, async: false

  alias BrainCloud.Agents
  alias BrainCloud.Memories.Memory
  alias BrainCloud.Projects
  alias BrainCloud.Repo

  test "PostgreSQL rejects audit events without an actor" do
    identity = identity_fixture()

    assert_constraint("audit_events_exactly_one_actor_check", fn ->
      Repo.query(audit_insert_sql(), [
        uuid(Ecto.UUID.generate()),
        uuid(identity.organization.id),
        nil,
        nil,
        uuid(Ecto.UUID.generate())
      ])
    end)
  end

  test "PostgreSQL rejects audit events with two actors" do
    identity = identity_fixture()
    {:ok, agent} = Agents.create_agent(%{name: "Same tenant"}, identity.auth_context)

    assert_constraint("audit_events_exactly_one_actor_check", fn ->
      Repo.query(audit_insert_sql(), [
        uuid(Ecto.UUID.generate()),
        uuid(identity.organization.id),
        uuid(identity.user.id),
        uuid(agent.id),
        uuid(Ecto.UUID.generate())
      ])
    end)
  end

  test "PostgreSQL rejects cross-organization agent audit provenance" do
    identity = identity_fixture()
    other_identity = identity_fixture()
    {:ok, other_agent} = Agents.create_agent(%{name: "Other tenant"}, other_identity.auth_context)

    assert_constraint("audit_events_actor_agent_tenant_fkey", fn ->
      Repo.query(audit_insert_sql(), [
        uuid(Ecto.UUID.generate()),
        uuid(identity.organization.id),
        nil,
        uuid(other_agent.id),
        uuid(Ecto.UUID.generate())
      ])
    end)
  end

  test "PostgreSQL rejects cross-organization agent memory provenance" do
    identity = identity_fixture()
    other_identity = identity_fixture()
    {:ok, project} = Projects.create_project(%{name: "Tenant boundary"}, identity.auth_context)
    memory = Repo.insert!(Memory.changeset(%Memory{}, %{project_id: project.id}))
    {:ok, other_agent} = Agents.create_agent(%{name: "Other tenant"}, other_identity.auth_context)

    assert_constraint("memory_revisions_actor_agent_tenant_check", fn ->
      Repo.query(
        """
        INSERT INTO memory_revisions (
          id, memory_id, revision_number, title, content, content_type,
          content_hash, actor_user_id, actor_agent_id, inserted_at, updated_at
        ) VALUES ($1, $2, 1, 'Cross tenant', 'Body', 'text/markdown', $3, NULL, $4, NOW(), NOW())
        """,
        [
          uuid(Ecto.UUID.generate()),
          uuid(memory.id),
          Base.encode16(:crypto.hash(:sha256, "Body"), case: :lower),
          uuid(other_agent.id)
        ]
      )
    end)
  end

  defp assert_constraint(constraint, operation) do
    assert {:error, %Postgrex.Error{postgres: %{constraint: ^constraint}}} = operation.()
  end

  defp audit_insert_sql do
    """
    INSERT INTO audit_events (
      id, organization_id, actor_user_id, actor_agent_id, action,
      resource_type, resource_id, metadata, inserted_at
    ) VALUES ($1, $2, $3, $4, 'memory.create', 'memory', $5, '{}'::jsonb, NOW())
    """
  end

  defp uuid(value), do: Ecto.UUID.dump!(value)
end
