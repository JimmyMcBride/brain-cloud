defmodule BrainCloudWeb.ProjectAccessControllerTest do
  use BrainCloudWeb.ConnCase, async: true

  alias BrainCloud.Accounts
  alias BrainCloud.Accounts.OrganizationMembership
  alias BrainCloud.Projects
  alias BrainCloud.Repo

  test "lists, grants, changes, and idempotently revokes project access", %{
    conn: conn,
    identity: identity
  } do
    {:ok, project} = Projects.create_project(%{name: "Access"}, identity.auth_context)
    first = membership_fixture(identity, "first")
    second = membership_fixture(identity, "second")

    assert %{"access_grant" => first_grant} =
             conn
             |> authenticate(identity)
             |> put(~p"/v1/projects/#{project.id}/access/#{first.id}", %{access: "reader"})
             |> json_response(200)

    assert first_grant == %{
             "id" => first_grant["id"],
             "project_id" => project.id,
             "membership_id" => first.id,
             "access" => "reader",
             "inserted_at" => first_grant["inserted_at"],
             "updated_at" => first_grant["updated_at"]
           }

    assert %{"access_grant" => second_grant} =
             conn
             |> recycle()
             |> authenticate(identity)
             |> put(~p"/v1/projects/#{project.id}/access/#{second.id}", %{access: "editor"})
             |> json_response(200)

    assert %{"access_grant" => changed_grant} =
             conn
             |> recycle()
             |> authenticate(identity)
             |> put(~p"/v1/projects/#{project.id}/access/#{first.id}", %{access: "editor"})
             |> json_response(200)

    assert changed_grant["id"] == first_grant["id"]
    assert changed_grant["access"] == "editor"

    assert %{"access_grant" => ^changed_grant} =
             conn
             |> recycle()
             |> authenticate(identity)
             |> put(~p"/v1/projects/#{project.id}/access/#{first.id}", %{access: "editor"})
             |> json_response(200)

    assert %{"access_grants" => grants} =
             conn
             |> recycle()
             |> authenticate(identity)
             |> get(~p"/v1/projects/#{project.id}/access")
             |> json_response(200)

    assert Enum.map(grants, & &1["id"]) ==
             [first_grant, second_grant]
             |> Enum.sort_by(&{&1["inserted_at"], &1["id"]})
             |> Enum.map(& &1["id"])

    assert conn
           |> recycle()
           |> authenticate(identity)
           |> delete(~p"/v1/projects/#{project.id}/access/#{first.id}")
           |> response(204) == ""

    assert conn
           |> recycle()
           |> authenticate(identity)
           |> delete(~p"/v1/projects/#{project.id}/access/#{first.id}")
           |> response(204) == ""
  end

  test "returns exact resource, inactive-membership, and access validation errors", %{
    conn: conn,
    identity: identity
  } do
    {:ok, project} = Projects.create_project(%{name: "Access errors"}, identity.auth_context)
    membership = membership_fixture(identity, "errors")
    other_identity = BrainCloud.DataCase.identity_fixture()
    missing_id = Ecto.UUID.generate()

    assert error_code(
             conn
             |> authenticate(identity)
             |> get("/v1/projects/not-a-uuid/access")
             |> json_response(404)
           ) == "project_not_found"

    assert error_code(
             conn
             |> recycle()
             |> authenticate(identity)
             |> put(~p"/v1/projects/#{project.id}/access/not-a-uuid", %{access: "reader"})
             |> json_response(404)
           ) == "membership_not_found"

    assert error_code(
             conn
             |> recycle()
             |> authenticate(identity)
             |> put(~p"/v1/projects/#{missing_id}/access/#{membership.id}", %{access: "reader"})
             |> json_response(404)
           ) == "project_not_found"

    assert error_code(
             conn
             |> recycle()
             |> authenticate(identity)
             |> put(~p"/v1/projects/#{project.id}/access/#{missing_id}", %{access: "reader"})
             |> json_response(404)
           ) == "membership_not_found"

    assert error_code(
             conn
             |> recycle()
             |> authenticate(identity)
             |> put(~p"/v1/projects/#{project.id}/access/#{other_identity.membership.id}", %{
               access: "reader"
             })
             |> json_response(404)
           ) == "membership_not_found"

    assert %{
             "error" => %{
               "code" => "validation_failed",
               "details" => %{"access" => ["can't be blank"]}
             }
           } =
             conn
             |> recycle()
             |> authenticate(identity)
             |> put(~p"/v1/projects/#{project.id}/access/#{membership.id}", %{})
             |> json_response(422)

    assert %{
             "error" => %{
               "code" => "validation_failed",
               "details" => %{"access" => ["is invalid"]}
             }
           } =
             conn
             |> recycle()
             |> authenticate(identity)
             |> put(~p"/v1/projects/#{project.id}/access/#{membership.id}", %{access: "owner"})
             |> json_response(422)

    assert {:ok, _grant} =
             Projects.put_project_access_grant(
               project.id,
               membership.id,
               "reader",
               identity.auth_context
             )

    assert {:ok, _membership} =
             Accounts.deactivate_organization_membership(identity.auth_context, membership.id)

    assert error_code(
             conn
             |> recycle()
             |> authenticate(identity)
             |> put(~p"/v1/projects/#{project.id}/access/#{membership.id}", %{access: "reader"})
             |> json_response(409)
           ) == "membership_inactive"

    assert conn
           |> recycle()
           |> authenticate(identity)
           |> delete(~p"/v1/projects/#{project.id}/access/#{membership.id}")
           |> response(204) == ""
  end

  test "authorizes before lookup and conceals projects in other organizations", %{
    conn: conn,
    identity: identity
  } do
    other_identity = BrainCloud.DataCase.identity_fixture()
    {:ok, other_project} = Projects.create_project(%{name: "Other"}, other_identity.auth_context)
    missing_id = Ecto.UUID.generate()

    {:ok, _token, limited_raw} =
      Accounts.create_api_token(identity.auth_context, %{
        name: "No project access management",
        scopes: ["members.manage"]
      })

    assert error_code(
             conn
             |> put_req_header("authorization", "Bearer #{limited_raw}")
             |> get(~p"/v1/projects/#{missing_id}/access")
             |> json_response(403)
           ) == "forbidden"

    assert error_code(
             conn
             |> recycle()
             |> authenticate(identity)
             |> get(~p"/v1/projects/#{other_project.id}/access")
             |> json_response(404)
           ) == "project_not_found"

    identity.membership
    |> OrganizationMembership.changeset(%{role: "member"})
    |> Repo.update!()

    assert error_code(
             conn
             |> recycle()
             |> authenticate(identity)
             |> get(~p"/v1/projects/#{missing_id}/access")
             |> json_response(403)
           ) == "forbidden"
  end

  defp membership_fixture(identity, label) do
    {:ok, membership} =
      Accounts.create_organization_membership(identity.auth_context, %{
        email: "#{label}-#{Ecto.UUID.generate()}@example.test",
        display_name: "Access Member",
        role: "member"
      })

    membership
  end

  defp error_code(response), do: response["error"]["code"]
end
