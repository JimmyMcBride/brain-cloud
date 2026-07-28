defmodule BrainCloud.ProjectsTest do
  use BrainCloud.DataCase, async: true

  alias BrainCloud.Accounts.AuditEvent
  alias BrainCloud.Projects

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
end
