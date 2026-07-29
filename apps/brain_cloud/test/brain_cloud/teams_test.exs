defmodule BrainCloud.TeamsTest do
  use BrainCloud.DataCase, async: false

  alias BrainCloud.Accounts
  alias BrainCloud.Accounts.AuditEvent
  alias BrainCloud.Projects
  alias BrainCloud.Projects.TeamProjectAccessGrant
  alias BrainCloud.Teams
  alias BrainCloud.Teams.TeamMembership

  setup do
    %{identity: identity_fixture()}
  end

  test "normalizes, lists, renames, and softly deactivates teams with no-op audits", %{
    identity: identity
  } do
    assert {:ok, team} = Teams.create_team(%{name: "  Platform  "}, identity.auth_context)
    assert team.name == "Platform"

    assert {:error, duplicate} =
             Teams.create_team(%{name: "platform"}, identity.auth_context)

    assert "has already been taken" in errors_on(duplicate).name
    assert {:ok, [^team]} = Teams.list_teams(identity.auth_context)

    count = Repo.aggregate(AuditEvent, :count, :id)
    assert {:ok, ^team} = Teams.rename_team(team.id, " Platform ", identity.auth_context)
    assert Repo.aggregate(AuditEvent, :count, :id) == count

    assert {:ok, renamed} = Teams.rename_team(team.id, "Core", identity.auth_context)
    assert renamed.name == "Core"
    assert {:ok, inactive} = Teams.deactivate_team(team.id, identity.auth_context)
    refute is_nil(inactive.deactivated_at)

    count = Repo.aggregate(AuditEvent, :count, :id)
    assert {:ok, _} = Teams.deactivate_team(team.id, identity.auth_context)
    assert Repo.aggregate(AuditEvent, :count, :id) == count

    assert {:ok, active} = Teams.reactivate_team(team.id, identity.auth_context)
    assert is_nil(active.deactivated_at)
  end

  test "retains membership links through lifecycle and rejects inactive additions", %{
    identity: identity
  } do
    membership = membership_fixture(identity, "linked")
    inactive = membership_fixture(identity, "inactive")
    {:ok, team} = Teams.create_team(%{name: "Readers"}, identity.auth_context)

    assert {:ok, link} =
             Teams.put_team_membership(team.id, membership.id, identity.auth_context)

    assert {:ok, ^link} =
             Teams.put_team_membership(team.id, membership.id, identity.auth_context)

    assert {:ok, [^link]} = Teams.list_team_memberships(team.id, identity.auth_context)
    assert {:ok, _} = Teams.deactivate_team(team.id, identity.auth_context)

    assert {:error, :team_inactive} =
             Teams.put_team_membership(team.id, inactive.id, identity.auth_context)

    assert {:ok, _} =
             Accounts.deactivate_organization_membership(identity.auth_context, inactive.id)

    assert {:ok, _} = Teams.reactivate_team(team.id, identity.auth_context)

    assert {:error, :membership_inactive} =
             Teams.put_team_membership(team.id, inactive.id, identity.auth_context)

    assert :ok = Teams.delete_team_membership(team.id, membership.id, identity.auth_context)
    assert :ok = Teams.delete_team_membership(team.id, membership.id, identity.auth_context)
  end

  test "team grants provide immediate strongest access and become dormant while inactive", %{
    identity: identity
  } do
    membership = membership_fixture(identity, "access")
    member_auth = member_auth_fixture(identity, membership, ["memory.read", "memory.write"])
    {:ok, project} = Projects.create_project(%{name: "Team project"}, identity.auth_context)
    {:ok, team} = Teams.create_team(%{name: "Editors"}, identity.auth_context)
    {:ok, _link} = Teams.put_team_membership(team.id, membership.id, identity.auth_context)

    assert {:ok, grant} =
             Projects.put_team_project_access_grant(
               project.id,
               team.id,
               "reader",
               identity.auth_context
             )

    assert {:ok, _} = Projects.authorize_project(project.id, member_auth, :reader)

    assert {:error, :project_not_found} =
             Projects.authorize_project(project.id, member_auth, :editor)

    assert {:ok, changed} =
             Projects.put_team_project_access_grant(
               project.id,
               team.id,
               "editor",
               identity.auth_context
             )

    assert changed.id == grant.id
    assert {:ok, _} = Projects.authorize_project(project.id, member_auth, :editor)

    assert {:ok, [^changed]} =
             Projects.list_team_project_access_grants(project.id, identity.auth_context)

    assert {:ok, _} = Teams.deactivate_team(team.id, identity.auth_context)

    assert {:error, :project_not_found} =
             Projects.authorize_project(project.id, member_auth, :reader)

    assert Repo.get!(TeamProjectAccessGrant, grant.id)

    assert {:error, :team_inactive} =
             Projects.put_team_project_access_grant(
               project.id,
               team.id,
               "reader",
               identity.auth_context
             )

    assert {:ok, _} = Teams.reactivate_team(team.id, identity.auth_context)
    assert {:ok, _} = Projects.authorize_project(project.id, member_auth, :editor)
  end

  test "database constraints reject cross-tenant links and grants", %{identity: identity} do
    other = identity_fixture()
    membership = membership_fixture(identity, "tenant")
    {:ok, team} = Teams.create_team(%{name: "Tenant"}, identity.auth_context)
    {:ok, project} = Projects.create_project(%{name: "Tenant"}, identity.auth_context)

    assert {:error, changeset} =
             %TeamMembership{}
             |> TeamMembership.changeset(%{
               organization_id: other.organization.id,
               team_id: team.id,
               organization_membership_id: other.membership.id
             })
             |> Repo.insert()

    assert "does not exist" in errors_on(changeset).team_id

    assert {:error, changeset} =
             %TeamProjectAccessGrant{}
             |> TeamProjectAccessGrant.changeset(%{
               organization_id: other.organization.id,
               project_id: project.id,
               team_id: other_team(other).id,
               access: "reader"
             })
             |> Repo.insert()

    assert "does not exist" in errors_on(changeset).project_id
    refute Repo.get_by(TeamMembership, organization_membership_id: membership.id)
  end

  test "concurrent identical membership and grant puts converge with one audit", %{
    identity: identity
  } do
    membership = membership_fixture(identity, "concurrent")
    {:ok, team} = Teams.create_team(%{name: "Concurrent"}, identity.auth_context)
    {:ok, project} = Projects.create_project(%{name: "Concurrent"}, identity.auth_context)

    membership_results =
      1..2
      |> Enum.map(fn _ ->
        Task.async(fn ->
          Teams.put_team_membership(team.id, membership.id, identity.auth_context)
        end)
      end)
      |> Enum.map(&Task.await(&1, 5_000))

    assert Enum.all?(membership_results, &match?({:ok, %TeamMembership{}}, &1))
    assert Repo.aggregate(TeamMembership, :count, :id) == 1

    assert Repo.aggregate(
             from(e in AuditEvent, where: e.action == "team_membership.add"),
             :count,
             :id
           ) == 1

    grant_results =
      1..2
      |> Enum.map(fn _ ->
        Task.async(fn ->
          Projects.put_team_project_access_grant(
            project.id,
            team.id,
            "reader",
            identity.auth_context
          )
        end)
      end)
      |> Enum.map(&Task.await(&1, 5_000))

    assert Enum.all?(grant_results, &match?({:ok, %TeamProjectAccessGrant{}}, &1))
    assert Repo.aggregate(TeamProjectAccessGrant, :count, :id) == 1

    assert Repo.aggregate(
             from(e in AuditEvent, where: e.action == "team_project_access.grant"),
             :count,
             :id
           ) == 1
  end

  test "concurrent case-insensitive names return validation instead of raising", %{
    identity: identity
  } do
    results =
      ["Collision", "collision"]
      |> Enum.map(fn name ->
        Task.async(fn -> Teams.create_team(%{name: name}, identity.auth_context) end)
      end)
      |> Enum.map(&Task.await(&1, 5_000))

    assert Enum.count(results, &match?({:ok, _}, &1)) == 1
    assert Enum.count(results, &match?({:error, %Ecto.Changeset{}}, &1)) == 1
  end

  defp other_team(identity) do
    {:ok, team} = Teams.create_team(%{name: "Other"}, identity.auth_context)
    team
  end

  defp membership_fixture(identity, label) do
    {:ok, membership} =
      Accounts.create_organization_membership(identity.auth_context, %{
        email: "#{label}-#{Ecto.UUID.generate()}@example.test",
        display_name: "Team Member",
        role: "member"
      })

    membership
  end

  defp member_auth_fixture(identity, membership, scopes) do
    {:ok, _token, raw_token} =
      Accounts.create_membership_api_token(identity.auth_context, membership.id, %{
        name: "Team member",
        scopes: scopes
      })

    {:ok, auth} = Accounts.authenticate(raw_token)
    auth
  end
end
