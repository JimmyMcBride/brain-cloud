defmodule BrainCloud.AgentMemoryWriteRaceTest do
  use ExUnit.Case, async: false

  import Ecto.Query
  import BrainCloud.DataCase, only: [identity_fixture: 0]

  alias BrainCloud.Accounts
  alias BrainCloud.Accounts.AuditEvent
  alias BrainCloud.Agents
  alias BrainCloud.Memories
  alias BrainCloud.Memories.Memory
  alias BrainCloud.Projects
  alias BrainCloud.Repo
  alias Ecto.Adapters.SQL.Sandbox

  @memory_attrs %{title: "Race", content: "Linearized", content_type: "text/markdown"}

  test "memory creation linearizes with agent deactivation" do
    setup = unboxed(fn -> writer_setup("Deactivate") end)
    on_exit(fn -> unboxed(fn -> cleanup(setup) end) end)

    assert_linearized_write(setup, fn ->
      assert {:ok, _agent} = Agents.deactivate_agent(setup.agent.id, setup.owner_auth)
    end)

    assert {:error, :project_not_found} =
             unboxed(fn ->
               Memories.create_memory(setup.project.id, @memory_attrs, setup.agent_auth)
             end)
  end

  test "memory creation linearizes with credential revocation" do
    setup = unboxed(fn -> writer_setup("Revoke") end)
    on_exit(fn -> unboxed(fn -> cleanup(setup) end) end)

    assert_linearized_write(setup, fn ->
      assert :ok =
               Agents.revoke_agent_token(
                 setup.agent.id,
                 setup.token.id,
                 setup.owner_auth
               )
    end)

    assert {:error, :project_not_found} =
             unboxed(fn ->
               Memories.create_memory(setup.project.id, @memory_attrs, setup.agent_auth)
             end)
  end

  test "memory creation linearizes with editor grant removal" do
    setup = unboxed(fn -> writer_setup("Grant removal") end)
    on_exit(fn -> unboxed(fn -> cleanup(setup) end) end)

    assert_linearized_write(setup, fn ->
      assert :ok =
               Projects.delete_agent_project_access_grant(
                 setup.project.id,
                 setup.agent.id,
                 setup.owner_auth
               )
    end)

    assert {:error, :project_not_found} =
             unboxed(fn ->
               Memories.create_memory(setup.project.id, @memory_attrs, setup.agent_auth)
             end)
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
    memory_count = unboxed(fn -> project_memory_count(setup.project.id) end)
    audit_count = unboxed(fn -> memory_audit_count(setup.owner_auth.organization_id) end)
    parent = self()

    write =
      Task.async(fn ->
        unboxed(fn ->
          backend_pid = backend_pid()
          send(parent, {:race_ready, :write, self(), backend_pid})
          receive do: (:race_go -> :ok)

          {backend_pid, Memories.create_memory(setup.project.id, @memory_attrs, setup.agent_auth)}
        end)
      end)

    mutate =
      Task.async(fn ->
        unboxed(fn ->
          backend_pid = backend_pid()
          send(parent, {:race_ready, :mutation, self(), backend_pid})
          receive do: (:race_go -> :ok)

          {backend_pid, mutation.()}
        end)
      end)

    assert_receive {:race_ready, :write, write_pid, write_backend}, 5_000
    assert_receive {:race_ready, :mutation, mutate_pid, mutate_backend}, 5_000
    assert write_backend != mutate_backend

    send(write_pid, :race_go)
    send(mutate_pid, :race_go)

    {^write_backend, write_result} = Task.await(write, 5_000)
    {^mutate_backend, _mutation_result} = Task.await(mutate, 5_000)

    assert write_result == {:error, :project_not_found} or match?({:ok, %Memory{}}, write_result),
           "unexpected write result: #{inspect(write_result)}"

    committed = if match?({:ok, %Memory{}}, write_result), do: 1, else: 0

    assert unboxed(fn -> project_memory_count(setup.project.id) end) ==
             memory_count + committed

    assert unboxed(fn -> memory_audit_count(setup.owner_auth.organization_id) end) ==
             audit_count + committed
  end

  defp project_memory_count(project_id) do
    Repo.aggregate(from(memory in Memory, where: memory.project_id == ^project_id), :count, :id)
  end

  defp memory_audit_count(organization_id) do
    Repo.aggregate(
      from(event in AuditEvent,
        where: event.organization_id == ^organization_id and event.action == "memory.create"
      ),
      :count,
      :id
    )
  end

  defp backend_pid do
    %{rows: [[pid]]} = Repo.query!("SELECT pg_backend_pid()")
    pid
  end

  defp cleanup(setup) do
    organization_id = Ecto.UUID.dump!(setup.owner_auth.organization_id)
    user_id = Ecto.UUID.dump!(setup.owner_auth.user_id)

    for table <- [
          "audit_events",
          "agent_project_access_grants",
          "project_access_grants",
          "team_project_access_grants",
          "team_memberships",
          "teams",
          "projects"
        ] do
      Repo.query!("DELETE FROM #{table} WHERE organization_id = $1", [organization_id])
    end

    Repo.query!(
      """
      DELETE FROM api_tokens
      WHERE membership_id IN (
        SELECT id FROM organization_memberships WHERE organization_id = $1
      ) OR agent_id IN (
        SELECT id FROM agents WHERE organization_id = $1
      )
      """,
      [organization_id]
    )

    Repo.query!("DELETE FROM agents WHERE organization_id = $1", [organization_id])

    Repo.query!("DELETE FROM organization_memberships WHERE organization_id = $1", [
      organization_id
    ])

    Repo.query!("DELETE FROM organizations WHERE id = $1", [organization_id])
    Repo.query!("DELETE FROM users WHERE id = $1", [user_id])
  end

  defp unboxed(fun), do: Sandbox.unboxed_run(Repo, fun)
end
