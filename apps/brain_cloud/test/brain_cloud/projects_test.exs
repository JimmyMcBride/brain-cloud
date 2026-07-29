defmodule BrainCloud.ProjectsTest do
  use BrainCloud.DataCase, async: true

  alias BrainCloud.Accounts.AuditEvent
  alias BrainCloud.Accounts
  alias BrainCloud.Projects
  alias BrainCloud.Projects.ProjectAccessGrant

  setup do
    %{identity: identity_fixture()}
  end

  test "creates a project with tenant and actor provenance", %{identity: identity} do
    assert {:ok, project} =
             Projects.create_project(%{"name" => "  Research  "}, identity.auth_context)

    assert project.name == "Research"
    assert project.creator_actor_id == identity.user.id
    assert project.organization_id == identity.organization.id
    assert project.id
    assert project.inserted_at

    assert Projects.get_project(project.id, identity.organization.id).id == project.id
    assert Projects.get_project(project.id, Ecto.UUID.generate()) == nil

    event = Repo.get_by!(AuditEvent, action: "project.create", resource_id: project.id)
    assert event.organization_id == identity.organization.id
    assert event.actor_user_id == identity.user.id
    assert event.api_token_id == identity.token.id
    assert event.metadata == %{}
  end

  test "validates project names", %{identity: identity} do
    audit_count = Repo.aggregate(AuditEvent, :count, :id)

    assert {:error, changeset} =
             Projects.create_project(%{"name" => "   "}, identity.auth_context)

    assert "can't be blank" in errors_on(changeset).name

    assert {:error, changeset} =
             Projects.create_project(
               %{"name" => String.duplicate("a", 121)},
               identity.auth_context
             )

    assert "should be at most 120 character(s)" in errors_on(changeset).name
    assert Repo.aggregate(AuditEvent, :count, :id) == audit_count
  end

  test "member project creators receive editor access while owners remain implicit", %{
    identity: identity
  } do
    membership = membership_fixture(identity)
    member_auth = member_auth_fixture(identity, membership, ["projects.create"])

    assert {:ok, member_project} =
             Projects.create_project(%{name: "Member project"}, member_auth)

    assert %ProjectAccessGrant{access: "editor"} =
             Repo.get_by(ProjectAccessGrant,
               project_id: member_project.id,
               organization_membership_id: membership.id
             )

    assert {:ok, _project} = Projects.authorize_project(member_project.id, member_auth, :editor)

    assert {:ok, owner_project} =
             Projects.create_project(%{name: "Owner project"}, identity.auth_context)

    refute Repo.get_by(ProjectAccessGrant,
             project_id: owner_project.id,
             organization_membership_id: identity.membership.id
           )

    assert {:ok, _project} =
             Projects.authorize_project(owner_project.id, identity.auth_context, :editor)
  end

  test "owners grant, change, list, and idempotently revoke project access with audit", %{
    identity: identity
  } do
    membership = membership_fixture(identity)
    {:ok, project} = Projects.create_project(%{name: "Access"}, identity.auth_context)

    assert {:ok, reader} =
             Projects.put_project_access_grant(
               project.id,
               membership.id,
               "reader",
               identity.auth_context
             )

    member_auth = member_auth_fixture(identity, membership, ["memory.read", "memory.write"])
    assert {:ok, _project} = Projects.authorize_project(project.id, member_auth, :reader)

    assert {:error, :project_not_found} =
             Projects.authorize_project(project.id, member_auth, :editor)

    assert {:ok, [listed]} =
             Projects.list_project_access_grants(project.id, identity.auth_context)

    assert listed.id == reader.id

    assert {:ok, editor} =
             Projects.put_project_access_grant(
               project.id,
               membership.id,
               "editor",
               identity.auth_context
             )

    assert editor.id == reader.id
    assert {:ok, _project} = Projects.authorize_project(project.id, member_auth, :editor)

    audit_count = Repo.aggregate(AuditEvent, :count, :id)

    assert {:ok, ^editor} =
             Projects.put_project_access_grant(
               project.id,
               membership.id,
               "editor",
               identity.auth_context
             )

    assert Repo.aggregate(AuditEvent, :count, :id) == audit_count

    assert :ok =
             Projects.delete_project_access_grant(
               project.id,
               membership.id,
               identity.auth_context
             )

    assert :ok =
             Projects.delete_project_access_grant(
               project.id,
               membership.id,
               identity.auth_context
             )

    assert Repo.aggregate(AuditEvent, :count, :id) == audit_count + 1

    events =
      Repo.all(
        from event in AuditEvent,
          where:
            event.resource_type == "project_access_grant" and
              event.resource_id == ^reader.id,
          order_by: [asc: event.inserted_at, asc: event.id]
      )

    assert Enum.map(events, & &1.action) == [
             "project_access.grant",
             "project_access.change",
             "project_access.revoke"
           ]

    assert Enum.at(events, 0).metadata == %{
             "access" => "reader",
             "membership_id" => membership.id,
             "project_id" => project.id
           }

    assert Enum.at(events, 1).metadata["previous_access"] == "reader"
    assert Enum.at(events, 2).metadata["previous_access"] == "editor"
  end

  test "conceals tenant resources, rejects inactive grants, and enforces tenant foreign keys", %{
    identity: identity
  } do
    membership = membership_fixture(identity)
    other_identity = identity_fixture()
    {:ok, project} = Projects.create_project(%{name: "Tenant"}, identity.auth_context)

    assert {:error, :project_not_found} =
             Projects.put_project_access_grant(
               other_identity.organization.id,
               membership.id,
               "reader",
               identity.auth_context
             )

    assert {:error, :membership_not_found} =
             Projects.put_project_access_grant(
               project.id,
               other_identity.membership.id,
               "reader",
               identity.auth_context
             )

    assert {:ok, _membership} =
             Accounts.deactivate_organization_membership(identity.auth_context, membership.id)

    assert {:error, :membership_inactive} =
             Projects.put_project_access_grant(
               project.id,
               membership.id,
               "reader",
               identity.auth_context
             )

    assert {:error, changeset} =
             %ProjectAccessGrant{}
             |> ProjectAccessGrant.changeset(%{
               organization_id: other_identity.organization.id,
               project_id: project.id,
               organization_membership_id: other_identity.membership.id,
               access: "reader"
             })
             |> Repo.insert()

    assert "does not exist" in errors_on(changeset).project_id
  end

  test "keeps grants dormant across suspension and owner role transitions", %{
    identity: identity
  } do
    membership = membership_fixture(identity)
    member_auth = member_auth_fixture(identity, membership, ["memory.read"])
    {:ok, project} = Projects.create_project(%{name: "Lifecycle"}, identity.auth_context)

    assert {:ok, grant} =
             Projects.put_project_access_grant(
               project.id,
               membership.id,
               "reader",
               identity.auth_context
             )

    assert {:ok, _project} = Projects.authorize_project(project.id, member_auth, :reader)

    assert {:ok, _membership} =
             Accounts.deactivate_organization_membership(identity.auth_context, membership.id)

    assert {:error, :project_not_found} =
             Projects.authorize_project(project.id, member_auth, :reader)

    assert Repo.get!(ProjectAccessGrant, grant.id)

    assert {:ok, _membership} =
             Accounts.reactivate_organization_membership(identity.auth_context, membership.id)

    reactivated_auth = member_auth_fixture(identity, membership, ["memory.read"])
    assert {:ok, _project} = Projects.authorize_project(project.id, reactivated_auth, :reader)

    assert {:ok, _membership} =
             Accounts.update_organization_membership_role(
               identity.auth_context,
               membership.id,
               "owner"
             )

    assert {:ok, _token, owner_raw_token} =
             Accounts.create_membership_api_token(
               identity.auth_context,
               membership.id,
               %{name: "Promoted owner", scopes: ["memory.read"]}
             )

    assert {:ok, owner_auth} = Accounts.authenticate(owner_raw_token)
    assert {:ok, _project} = Projects.authorize_project(project.id, owner_auth, :editor)
    assert Repo.get!(ProjectAccessGrant, grant.id)

    assert {:ok, owner_project} =
             Projects.create_project(%{name: "Implicit owner project"}, owner_auth)

    refute Repo.get_by(ProjectAccessGrant,
             project_id: owner_project.id,
             organization_membership_id: membership.id
           )

    assert {:ok, _membership} =
             Accounts.update_organization_membership_role(
               identity.auth_context,
               membership.id,
               "member"
             )

    demoted_auth = member_auth_fixture(identity, membership, ["memory.read"])
    assert {:ok, _project} = Projects.authorize_project(project.id, demoted_auth, :reader)

    assert {:error, :project_not_found} =
             Projects.authorize_project(project.id, demoted_auth, :editor)

    assert {:error, :project_not_found} =
             Projects.authorize_project(owner_project.id, demoted_auth, :reader)
  end

  defp membership_fixture(identity) do
    suffix = Ecto.UUID.generate()

    {:ok, membership} =
      Accounts.create_organization_membership(identity.auth_context, %{
        email: "project-member-#{suffix}@example.test",
        display_name: "Project Member",
        role: "member"
      })

    membership
  end

  defp member_auth_fixture(identity, membership, scopes) do
    {:ok, _token, raw_token} =
      Accounts.create_membership_api_token(identity.auth_context, membership.id, %{
        name: "Project member",
        scopes: scopes
      })

    {:ok, auth} = Accounts.authenticate(raw_token)
    auth
  end
end
