defmodule BrainCloud.AgentMemoryWriteRaceTest do
  use BrainCloud.DataCase, async: false

  alias BrainCloud.Accounts
  alias BrainCloud.Accounts.AuditEvent
  alias BrainCloud.Agents
  alias BrainCloud.Memories
  alias BrainCloud.Memories.Memory
  alias BrainCloud.Projects
  alias BrainCloud.Repo

  @memory_attrs %{title: "Race", content: "Linearized", content_type: "text/markdown"}

  test "memory creation linearizes with agent deactivation" do
    setup = writer_setup("Deactivate")

    assert_linearized_write(setup, fn ->
      assert {:ok, _agent} = Agents.deactivate_agent(setup.agent.id, setup.owner_auth)
    end)

    assert {:error, :project_not_found} =
             Memories.create_memory(setup.project.id, @memory_attrs, setup.agent_auth)
  end

  test "memory creation linearizes with credential revocation" do
    setup = writer_setup("Revoke")

    assert_linearized_write(setup, fn ->
      assert :ok =
               Agents.revoke_agent_token(
                 setup.agent.id,
                 setup.token.id,
                 setup.owner_auth
               )
    end)

    assert {:error, :project_not_found} =
             Memories.create_memory(setup.project.id, @memory_attrs, setup.agent_auth)
  end

  test "memory creation linearizes with editor grant removal" do
    setup = writer_setup("Grant removal")

    assert_linearized_write(setup, fn ->
      assert :ok =
               Projects.delete_agent_project_access_grant(
                 setup.project.id,
                 setup.agent.id,
                 setup.owner_auth
               )
    end)

    assert {:error, :project_not_found} =
             Memories.create_memory(setup.project.id, @memory_attrs, setup.agent_auth)
  end

  defp writer_setup(name) do
    identity = identity_fixture()
    {:ok, project} = Projects.create_project(%{name: name}, identity.auth_context)
    {:ok, agent} = Agents.create_agent(%{name: name}, identity.auth_context)

    {:ok, _grant} =
      Projects.put_agent_project_access_grant(
        project.id,
        agent.id,
        "editor",
        identity.auth_context
      )

    {:ok, token, raw} =
      Agents.create_agent_token(
        agent.id,
        %{name: name, scopes: ["memory.write"]},
        identity.auth_context
      )

    {:ok, agent_auth} = Accounts.authenticate(raw)

    %{
      owner_auth: identity.auth_context,
      project: project,
      agent: agent,
      token: token,
      agent_auth: agent_auth
    }
  end

  defp assert_linearized_write(setup, mutation) do
    memory_count = Repo.aggregate(Memory, :count, :id)
    audit_count = memory_audit_count()

    write =
      Task.async(fn ->
        Memories.create_memory(setup.project.id, @memory_attrs, setup.agent_auth)
      end)

    mutate = Task.async(mutation)
    write_result = Task.await(write, 5_000)
    Task.await(mutate, 5_000)

    assert write_result == {:error, :project_not_found} or match?({:ok, %Memory{}}, write_result),
           "unexpected write result: #{inspect(write_result)}"

    committed = if match?({:ok, %Memory{}}, write_result), do: 1, else: 0
    assert Repo.aggregate(Memory, :count, :id) == memory_count + committed
    assert memory_audit_count() == audit_count + committed
  end

  defp memory_audit_count do
    Repo.aggregate(from(event in AuditEvent, where: event.action == "memory.create"), :count, :id)
  end
end
