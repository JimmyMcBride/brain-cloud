defmodule BrainCloud.ProjectDiscoveryTest do
  use BrainCloud.DataCase, async: true

  alias BrainCloud.Accounts
  alias BrainCloud.Agents
  alias BrainCloud.Projects
  alias BrainCloud.Projects.Project
  alias BrainCloud.Repo
  alias BrainCloud.Teams

  setup do
    %{identity: identity_fixture()}
  end

  test "members discover the distinct union of direct and active-team grants", %{identity: owner} do
    member = membership_fixture(owner)
    auth = membership_auth(owner, member, ["projects.read"])
    {:ok, direct} = Projects.create_project(%{name: "Direct"}, owner.auth_context)
    {:ok, team_project} = Projects.create_project(%{name: "Team"}, owner.auth_context)
    {:ok, hidden} = Projects.create_project(%{name: "Hidden"}, owner.auth_context)
    {:ok, team} = Teams.create_team(%{name: "Readers"}, owner.auth_context)

    {:ok, _} = Teams.put_team_membership(team.id, member.id, owner.auth_context)

    {:ok, _} =
      Projects.put_project_access_grant(direct.id, member.id, "reader", owner.auth_context)

    {:ok, _} =
      Projects.put_team_project_access_grant(direct.id, team.id, "reader", owner.auth_context)

    {:ok, _} =
      Projects.put_team_project_access_grant(
        team_project.id,
        team.id,
        "editor",
        owner.auth_context
      )

    {projects, false} = Projects.list_projects(auth, 100)
    assert Enum.map(projects, & &1.id) |> Enum.sort() == Enum.sort([direct.id, team_project.id])
    refute Enum.any?(projects, &(&1.id == hidden.id))

    {:ok, _team} = Teams.deactivate_team(team.id, owner.auth_context)
    {projects, false} = Projects.list_projects(auth, 100)
    assert Enum.map(projects, & &1.id) == [direct.id]
  end

  test "agents discover only direct grants and lifecycle changes apply on the next query", %{
    identity: owner
  } do
    {:ok, agent} = Agents.create_agent(%{name: "Reader"}, owner.auth_context)

    {:ok, _token, raw_token} =
      Agents.create_agent_token(
        agent.id,
        %{name: "Discovery", scopes: ["projects.read"]},
        owner.auth_context
      )

    {:ok, auth} = Accounts.authenticate(raw_token)
    {:ok, project} = Projects.create_project(%{name: "Granted"}, owner.auth_context)
    {:ok, _hidden} = Projects.create_project(%{name: "Hidden"}, owner.auth_context)

    {:ok, _} =
      Projects.put_agent_project_access_grant(
        project.id,
        agent.id,
        "reader",
        owner.auth_context
      )

    assert {[%{id: id}], false} = Projects.list_projects(auth, 20)
    assert id == project.id

    :ok =
      Projects.delete_agent_project_access_grant(project.id, agent.id, owner.auth_context)

    assert {[], false} = Projects.list_projects(auth, 20)
  end

  test "keyset pagination is deterministic for equal timestamps and a removed anchor", %{
    identity: owner
  } do
    projects =
      for name <- ["One", "Two", "Three"] do
        {:ok, project} = Projects.create_project(%{name: name}, owner.auth_context)
        project
      end

    inserted_at = ~U[2026-09-08 01:02:03.123456Z]
    ids = Enum.map(projects, & &1.id)

    from(project in Project, where: project.id in ^ids)
    |> Repo.update_all(set: [inserted_at: inserted_at])

    {[first], true} = Projects.list_projects(owner.auth_context, 1)
    Repo.delete!(first)

    {remaining, false} =
      Projects.list_projects(owner.auth_context, 100, {inserted_at, first.id})

    assert Enum.map(remaining, & &1.id) == ids |> Enum.reject(&(&1 == first.id)) |> Enum.sort()
  end

  test "projects.read is explicitly issuable without widening existing credentials", %{
    identity: owner
  } do
    {:ok, narrow_token, _raw} =
      Accounts.create_api_token(owner.auth_context, %{
        name: "Narrow",
        scopes: ["memory.read"]
      })

    {:ok, invitation, _acceptance_token} =
      Accounts.create_organization_invitation(owner.auth_context, %{
        email: "project-reader-#{Ecto.UUID.generate()}@example.test",
        display_name: "Project reader",
        scopes: ["projects.read"],
        expires_at: DateTime.add(DateTime.utc_now(:microsecond), 3600, :second)
      })

    assert invitation.scopes == ["projects.read"]
    assert Repo.reload!(narrow_token).scopes == ["memory.read"]
  end

  defp membership_fixture(owner) do
    suffix = Ecto.UUID.generate()

    {:ok, membership} =
      Accounts.create_organization_membership(owner.auth_context, %{
        email: "discovery-#{suffix}@example.test",
        display_name: "Discovery member",
        role: "member"
      })

    membership
  end

  defp membership_auth(owner, membership, scopes) do
    {:ok, _token, raw_token} =
      Accounts.create_membership_api_token(owner.auth_context, membership.id, %{
        name: "Discovery",
        scopes: scopes
      })

    {:ok, auth} = Accounts.authenticate(raw_token)
    auth
  end
end
