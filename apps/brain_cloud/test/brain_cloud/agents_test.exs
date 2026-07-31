defmodule BrainCloud.AgentsTest do
  use BrainCloud.DataCase, async: false

  alias BrainCloud.Accounts
  alias BrainCloud.Accounts.ApiToken
  alias BrainCloud.Accounts.AuditEvent
  alias BrainCloud.Agents
  alias BrainCloud.Agents.Agent
  alias BrainCloud.Repo

  test "manages agent lifecycle, credentials, exact identity, and audits" do
    identity = identity_fixture()
    auth = identity.auth_context

    assert {:ok, agent} = Agents.create_agent(%{name: "  Researcher  "}, auth)
    assert agent.name == "Researcher"
    assert {:ok, [listed]} = Agents.list_agents(auth)
    assert listed.id == agent.id

    audit_count = Repo.aggregate(AuditEvent, :count, :id)
    assert {:ok, same} = Agents.rename_agent(agent.id, "Researcher", auth)
    assert same.id == agent.id
    assert Repo.aggregate(AuditEvent, :count, :id) == audit_count

    assert {:ok, renamed} = Agents.rename_agent(agent.id, "Retriever", auth)
    assert renamed.name == "Retriever"

    assert {:ok, token, raw_token} =
             Agents.create_agent_token(
               agent.id,
               %{name: "Read token", scopes: ["memory.read", "search.keyword"]},
               auth
             )

    refute token.bootstrap
    assert {:ok, agent_auth} = Accounts.authenticate(raw_token)
    assert agent_auth.principal_type == :agent
    assert agent_auth.principal_id == agent.id
    assert agent_auth.agent_id == agent.id
    assert agent_auth.user_id == nil
    assert agent_auth.membership_id == nil
    assert agent_auth.role == "agent"

    assert {:ok, [listed_token]} = Agents.list_agent_tokens(agent.id, auth)
    assert listed_token.id == token.id

    assert {:ok, inactive} = Agents.deactivate_agent(agent.id, auth)
    assert inactive.deactivated_at
    assert {:error, :unauthorized} = Accounts.authenticate(raw_token)
    assert Repo.get!(ApiToken, token.id).revoked_at

    event = Repo.get_by!(AuditEvent, action: "agent.deactivate", resource_id: agent.id)
    assert event.metadata == %{"revoked_token_count" => 1}
    refute Repo.get_by(AuditEvent, action: "agent_token.revoke", resource_id: token.id)

    audit_count = Repo.aggregate(AuditEvent, :count, :id)
    assert {:ok, _inactive} = Agents.deactivate_agent(agent.id, auth)
    assert Repo.aggregate(AuditEvent, :count, :id) == audit_count

    assert {:error, :agent_inactive} =
             Agents.create_agent_token(
               agent.id,
               %{name: "Blocked", scopes: ["memory.read"]},
               auth
             )

    assert {:ok, active} = Agents.reactivate_agent(agent.id, auth)
    assert active.deactivated_at == nil
    assert {:error, :unauthorized} = Accounts.authenticate(raw_token)

    assert {:ok, replacement, replacement_raw} =
             Agents.create_agent_token(
               agent.id,
               %{name: "Replacement", scopes: ["memory.read"]},
               auth
             )

    assert {:ok, _agent_auth} = Accounts.authenticate(replacement_raw)
    assert :ok = Agents.revoke_agent_token(agent.id, replacement.id, auth)
    assert {:error, :unauthorized} = Accounts.authenticate(replacement_raw)
    assert :ok = Agents.revoke_agent_token(agent.id, replacement.id, auth)

    revoke_events =
      Repo.aggregate(
        from(event in AuditEvent,
          where: event.action == "agent_token.revoke" and event.resource_id == ^replacement.id
        ),
        :count,
        :id
      )

    assert revoke_events == 1
  end

  test "rejects invalid agent names and credential scopes" do
    identity = identity_fixture()
    auth = identity.auth_context

    assert {:ok, agent} = Agents.create_agent(%{name: "Reader"}, auth)
    assert {:error, changeset} = Agents.create_agent(%{name: "reader"}, auth)
    assert "has already been taken" in errors_on(changeset).name

    for scopes <- [
          [],
          ["memory.write"],
          ["agents.manage"],
          ["unknown.scope"],
          ["memory.read", "tokens.manage"]
        ] do
      assert {:error, changeset} =
               Agents.create_agent_token(
                 agent.id,
                 %{name: "Invalid", scopes: scopes},
                 auth
               )

      assert errors_on(changeset).scopes
    end
  end

  test "rejects expired agent credentials and conflicting renames" do
    identity = identity_fixture()
    auth = identity.auth_context
    assert {:ok, first} = Agents.create_agent(%{name: "First"}, auth)
    assert {:ok, second} = Agents.create_agent(%{name: "Second"}, auth)

    assert {:error, changeset} = Agents.rename_agent(second.id, " first ", auth)
    assert "has already been taken" in errors_on(changeset).name
    assert Repo.get!(Agent, second.id).name == "Second"

    assert {:ok, token, raw} =
             Agents.create_agent_token(
               first.id,
               %{
                 name: "Expired",
                 scopes: ["memory.read"],
                 expires_at: DateTime.add(DateTime.utc_now(), -1, :second)
               },
               auth
             )

    assert token.expires_at
    assert {:error, :unauthorized} = Accounts.authenticate(raw)
  end

  test "conceals cross-tenant agents and nested tokens" do
    first = identity_fixture()
    second = identity_fixture()
    assert {:ok, agent} = Agents.create_agent(%{name: "Private"}, first.auth_context)

    assert {:ok, token, _raw} =
             Agents.create_agent_token(
               agent.id,
               %{name: "Private token", scopes: ["memory.read"]},
               first.auth_context
             )

    assert {:error, :agent_not_found} = Agents.list_agent_tokens(agent.id, second.auth_context)

    assert {:error, :agent_not_found} =
             Agents.revoke_agent_token(agent.id, token.id, second.auth_context)

    assert {:error, :agent_not_found} =
             Agents.revoke_agent_token("not-a-uuid", "not-a-uuid", first.auth_context)

    assert {:error, :token_not_found} =
             Agents.revoke_agent_token(agent.id, "not-a-uuid", first.auth_context)
  end

  test "database enforces token principal and bootstrap invariants" do
    identity = identity_fixture()
    assert {:ok, agent} = Agents.create_agent(%{name: "Invariant"}, identity.auth_context)

    attrs = %{
      public_id: String.duplicate("a", 32),
      token_digest: :binary.copy(<<1>>, 32),
      name: "Invalid",
      scopes: ["memory.read"]
    }

    assert {:error, changeset} =
             attrs
             |> then(&struct!(ApiToken, &1))
             |> change()
             |> check_constraint(:membership_id,
               name: :api_tokens_exactly_one_principal_check
             )
             |> Repo.insert()

    assert "is invalid" in errors_on(changeset).membership_id

    assert {:error, changeset} =
             attrs
             |> Map.merge(%{
               public_id: String.duplicate("b", 32),
               agent_id: agent.id,
               membership_id: identity.membership.id
             })
             |> then(&struct!(ApiToken, &1))
             |> change()
             |> check_constraint(:membership_id,
               name: :api_tokens_exactly_one_principal_check
             )
             |> Repo.insert()

    assert "is invalid" in errors_on(changeset).membership_id

    assert {:error, changeset} =
             attrs
             |> Map.merge(%{
               public_id: String.duplicate("c", 32),
               agent_id: agent.id,
               bootstrap: true
             })
             |> then(&struct!(ApiToken, &1))
             |> change()
             |> check_constraint(:bootstrap, name: :api_tokens_agent_not_bootstrap_check)
             |> Repo.insert()

    assert "is invalid" in errors_on(changeset).bootstrap
  end

  test "inactive and active agents remain ordered and names remain reserved" do
    identity = identity_fixture()
    auth = identity.auth_context
    assert {:ok, first} = Agents.create_agent(%{name: "First"}, auth)
    assert {:ok, second} = Agents.create_agent(%{name: "Second"}, auth)
    assert {:ok, _} = Agents.deactivate_agent(first.id, auth)
    assert {:ok, agents} = Agents.list_agents(auth)
    assert Enum.map(agents, & &1.id) == [first.id, second.id]

    assert {:error, changeset} = Agents.create_agent(%{name: "FIRST"}, auth)
    assert "has already been taken" in errors_on(changeset).name
    assert Repo.get!(Agent, first.id).deactivated_at
  end

  test "concurrent normalized names create one agent" do
    identity = identity_fixture()

    results =
      ["Concurrent", " concurrent "]
      |> Enum.map(fn name ->
        Task.async(fn -> Agents.create_agent(%{name: name}, identity.auth_context) end)
      end)
      |> Enum.map(&Task.await(&1, 5_000))

    assert Enum.count(results, &match?({:ok, %Agent{}}, &1)) == 1
    assert Enum.count(results, &match?({:error, %Ecto.Changeset{}}, &1)) == 1
    assert Repo.aggregate(Agent, :count, :id) == 1
  end

  test "deactivation serializes credential issuance and leaves no usable token" do
    identity = identity_fixture()
    auth = identity.auth_context
    assert {:ok, agent} = Agents.create_agent(%{name: "Racing"}, auth)

    issue =
      Task.async(fn ->
        Agents.create_agent_token(
          agent.id,
          %{name: "Racing", scopes: ["memory.read"]},
          auth
        )
      end)

    deactivate = Task.async(fn -> Agents.deactivate_agent(agent.id, auth) end)

    issue_result = Task.await(issue, 5_000)
    assert {:ok, %Agent{deactivated_at: deactivated_at}} = Task.await(deactivate, 5_000)
    assert deactivated_at

    case issue_result do
      {:ok, token, raw} ->
        assert Repo.get!(ApiToken, token.id).revoked_at
        assert {:error, :unauthorized} = Accounts.authenticate(raw)

      {:error, :agent_inactive} ->
        assert Repo.aggregate(ApiToken, :count, :id) == 1
    end
  end
end
