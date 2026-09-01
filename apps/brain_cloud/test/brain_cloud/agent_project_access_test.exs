defmodule BrainCloud.AgentProjectAccessTest do
  use BrainCloud.DataCase, async: false

  alias BrainCloud.Accounts
  alias BrainCloud.Accounts.AuditEvent
  alias BrainCloud.Agents
  alias BrainCloud.Projects
  alias BrainCloud.Projects.AgentProjectAccessGrant
  alias BrainCloud.Repo

  test "agent reader grant and fixed scopes independently authorize retrieval" do
    identity = identity_fixture()
    auth = identity.auth_context
    {:ok, project} = Projects.create_project(%{name: "Agent Project"}, auth)
    {:ok, agent} = Agents.create_agent(%{name: "Reader"}, auth)

    assert {:error, :project_not_found} = agent_authorization(project.id, agent, auth)

    assert {:ok, grant} =
             Projects.put_agent_project_access_grant(project.id, agent.id, "reader", auth)

    assert grant.access == "reader"
    assert {:ok, grants} = Projects.list_agent_project_access_grants(project.id, auth)
    assert Enum.map(grants, & &1.id) == [grant.id]

    assert {:ok, _token, raw_token} =
             Agents.create_agent_token(
               agent.id,
               %{name: "Read", scopes: ["memory.read"]},
               auth
             )

    assert {:ok, agent_auth} = Accounts.authenticate(raw_token)
    assert {:ok, ^project} = Projects.authorize_project(project.id, agent_auth, :reader)

    assert {:error, :project_not_found} =
             Projects.authorize_project(project.id, agent_auth, :editor)

    assert :ok = Projects.delete_agent_project_access_grant(project.id, agent.id, auth)

    assert {:error, :project_not_found} =
             Projects.authorize_project(project.id, agent_auth, :reader)

    assert :ok = Projects.delete_agent_project_access_grant(project.id, agent.id, auth)
  end

  test "retains dormant grants across deactivation and reactivation" do
    identity = identity_fixture()
    auth = identity.auth_context
    {:ok, project} = Projects.create_project(%{name: "Dormant"}, auth)
    {:ok, agent} = Agents.create_agent(%{name: "Dormant"}, auth)

    assert {:ok, grant} =
             Projects.put_agent_project_access_grant(project.id, agent.id, "reader", auth)

    assert {:ok, _} = Agents.deactivate_agent(agent.id, auth)

    assert {:error, :agent_inactive} =
             Projects.put_agent_project_access_grant(project.id, agent.id, "reader", auth)

    assert {:ok, [retained]} = Projects.list_agent_project_access_grants(project.id, auth)
    assert retained.id == grant.id
    assert {:ok, _} = Agents.reactivate_agent(agent.id, auth)

    assert {:ok, _token, raw} =
             Agents.create_agent_token(
               agent.id,
               %{name: "Fresh", scopes: ["memory.read"]},
               auth
             )

    assert {:ok, agent_auth} = Accounts.authenticate(raw)
    assert {:ok, ^project} = Projects.authorize_project(project.id, agent_auth, :reader)
  end

  test "editor grants imply reads, change transactionally, and audit only real changes" do
    identity = identity_fixture()
    auth = identity.auth_context
    {:ok, project} = Projects.create_project(%{name: "Editor"}, auth)
    {:ok, agent} = Agents.create_agent(%{name: "Editor"}, auth)

    assert {:ok, reader} =
             Projects.put_agent_project_access_grant(project.id, agent.id, "reader", auth)

    assert {:ok, editor} =
             Projects.put_agent_project_access_grant(project.id, agent.id, "editor", auth)

    assert editor.id == reader.id
    assert editor.access == "editor"

    assert {:ok, same_editor} =
             Projects.put_agent_project_access_grant(project.id, agent.id, "editor", auth)

    assert same_editor.id == editor.id

    {:ok, _token, raw} =
      Agents.create_agent_token(
        agent.id,
        %{name: "Read and write", scopes: ["memory.read", "memory.write"]},
        auth
      )

    {:ok, agent_auth} = Accounts.authenticate(raw)
    assert {:ok, ^project} = Projects.authorize_project(project.id, agent_auth, :reader)
    assert {:ok, ^project} = Projects.authorize_project(project.id, agent_auth, :editor)

    changes =
      Repo.all(
        from event in AuditEvent,
          where:
            event.action == "agent_project_access.change" and
              event.resource_id == ^editor.id
      )

    assert [change] = changes
    assert change.metadata["previous_access"] == "reader"
    assert change.metadata["access"] == "editor"

    assert {:ok, downgraded} =
             Projects.put_agent_project_access_grant(project.id, agent.id, "reader", auth)

    assert downgraded.access == "reader"

    assert {:error, :project_not_found} =
             Projects.authorize_project(project.id, agent_auth, :editor)

    assert Repo.aggregate(
             from(e in AuditEvent, where: e.action == "agent_project_access.change"),
             :count,
             :id
           ) == 2
  end

  test "enforces project-first concealment and tenant constraints" do
    first = identity_fixture()
    second = identity_fixture()
    {:ok, project} = Projects.create_project(%{name: "First"}, first.auth_context)
    {:ok, agent} = Agents.create_agent(%{name: "Second"}, second.auth_context)

    assert {:error, :project_not_found} =
             Projects.put_agent_project_access_grant(
               "not-a-uuid",
               "not-a-uuid",
               "reader",
               first.auth_context
             )

    assert {:error, :agent_not_found} =
             Projects.put_agent_project_access_grant(
               project.id,
               "not-a-uuid",
               "reader",
               first.auth_context
             )

    assert {:error, :agent_not_found} =
             Projects.put_agent_project_access_grant(
               project.id,
               agent.id,
               "reader",
               first.auth_context
             )

    assert {:error, changeset} =
             %AgentProjectAccessGrant{}
             |> AgentProjectAccessGrant.changeset(%{
               organization_id: first.organization.id,
               project_id: project.id,
               agent_id: agent.id,
               access: "reader"
             })
             |> Repo.insert()

    assert "does not exist" in errors_on(changeset).agent_id
  end

  test "concurrent identical grants converge on one row and audit" do
    identity = identity_fixture()
    auth = identity.auth_context
    {:ok, project} = Projects.create_project(%{name: "Concurrent"}, auth)
    {:ok, agent} = Agents.create_agent(%{name: "Concurrent"}, auth)

    results =
      1..2
      |> Enum.map(fn _ ->
        Task.async(fn ->
          Projects.put_agent_project_access_grant(project.id, agent.id, "reader", auth)
        end)
      end)
      |> Enum.map(&Task.await(&1, 5_000))

    assert Enum.all?(results, &match?({:ok, %AgentProjectAccessGrant{}}, &1))
    assert Repo.aggregate(AgentProjectAccessGrant, :count, :id) == 1

    audit_count =
      Repo.aggregate(
        from(event in AuditEvent,
          where:
            event.action == "agent_project_access.grant" and
              fragment("?->>'agent_id'", event.metadata) == ^agent.id
        ),
        :count,
        :id
      )

    assert audit_count == 1
  end

  test "deactivation serializes grant creation and leaves access dormant" do
    identity = identity_fixture()
    auth = identity.auth_context
    {:ok, project} = Projects.create_project(%{name: "Grant race"}, auth)
    {:ok, agent} = Agents.create_agent(%{name: "Grant race"}, auth)

    grant =
      Task.async(fn ->
        Projects.put_agent_project_access_grant(project.id, agent.id, "reader", auth)
      end)

    deactivate = Task.async(fn -> Agents.deactivate_agent(agent.id, auth) end)

    grant_result = Task.await(grant, 5_000)
    assert {:ok, _inactive} = Task.await(deactivate, 5_000)

    assert grant_result == {:error, :agent_inactive} or
             match?({:ok, %AgentProjectAccessGrant{}}, grant_result)

    assert {:ok, _} = Agents.reactivate_agent(agent.id, auth)

    assert {:ok, _token, raw} =
             Agents.create_agent_token(agent.id, %{name: "Fresh", scopes: ["memory.read"]}, auth)

    assert {:ok, agent_auth} = Accounts.authenticate(raw)

    case grant_result do
      {:ok, _grant} ->
        assert {:ok, ^project} = Projects.authorize_project(project.id, agent_auth, :reader)

      {:error, :agent_inactive} ->
        assert {:error, :project_not_found} =
                 Projects.authorize_project(project.id, agent_auth, :reader)
    end
  end

  defp agent_authorization(project_id, agent, auth) do
    with {:ok, _token, raw} <-
           Agents.create_agent_token(
             agent.id,
             %{name: "Before grant", scopes: ["memory.read"]},
             auth
           ),
         {:ok, agent_auth} <- Accounts.authenticate(raw) do
      Projects.authorize_project(project_id, agent_auth, :reader)
    end
  end
end
