defmodule BrainCloudWeb.TeamAccessControllerTest do
  use BrainCloudWeb.ConnCase, async: true

  alias BrainCloud.Accounts
  alias BrainCloud.Projects

  test "serves exact team, membership, and project-grant contracts", %{
    conn: conn,
    identity: identity
  } do
    membership = membership_fixture(identity)
    {:ok, project} = Projects.create_project(%{name: "Team API"}, identity.auth_context)

    assert %{"team" => team} =
             conn
             |> authenticate(identity)
             |> post(~p"/v1/organization/teams", %{name: " Platform "})
             |> json_response(201)

    assert team == %{
             "id" => team["id"],
             "name" => "Platform",
             "active" => true,
             "deactivated_at" => nil,
             "inserted_at" => team["inserted_at"],
             "updated_at" => team["updated_at"]
           }

    assert %{"team_membership" => link} =
             conn
             |> recycle()
             |> authenticate(identity)
             |> put(~p"/v1/organization/teams/#{team["id"]}/members/#{membership.id}")
             |> json_response(200)

    assert Map.keys(link) |> Enum.sort() ==
             ~w(id inserted_at membership_id team_id)

    assert %{"team_access_grant" => grant} =
             conn
             |> recycle()
             |> authenticate(identity)
             |> put(~p"/v1/projects/#{project.id}/team-access/#{team["id"]}", %{access: "editor"})
             |> json_response(200)

    assert Map.keys(grant) |> Enum.sort() ==
             ~w(access id inserted_at project_id team_id updated_at)

    assert %{"teams" => [listed]} =
             conn
             |> recycle()
             |> authenticate(identity)
             |> get(~p"/v1/organization/teams")
             |> json_response(200)

    assert listed["id"] == team["id"]

    assert conn
           |> recycle()
           |> authenticate(identity)
           |> delete(~p"/v1/organization/teams/#{team["id"]}")
           |> response(204) == ""

    assert error_code(
             conn
             |> recycle()
             |> authenticate(identity)
             |> put(~p"/v1/projects/#{project.id}/team-access/#{team["id"]}", %{access: "reader"})
             |> json_response(409)
           ) == "team_inactive"

    assert %{"team_access_grants" => [_]} =
             conn
             |> recycle()
             |> authenticate(identity)
             |> get(~p"/v1/projects/#{project.id}/team-access")
             |> json_response(200)

    assert %{"team" => %{"active" => true}} =
             conn
             |> recycle()
             |> authenticate(identity)
             |> post(~p"/v1/organization/teams/#{team["id"]}/reactivate")
             |> json_response(200)
  end

  test "enforces scopes before lookup and preserves project-first errors", %{
    conn: conn,
    identity: identity
  } do
    missing = Ecto.UUID.generate()

    {:ok, _token, limited_raw} =
      Accounts.create_api_token(identity.auth_context, %{
        name: "Limited owner",
        scopes: ["projects.create"]
      })

    assert error_code(
             conn
             |> put_req_header("authorization", "Bearer #{limited_raw}")
             |> get(~p"/v1/organization/teams/#{missing}/members")
             |> json_response(403)
           ) == "forbidden"

    assert error_code(
             conn
             |> recycle()
             |> authenticate(identity)
             |> put("/v1/projects/not-a-uuid/team-access/not-a-uuid", %{access: "reader"})
             |> json_response(404)
           ) == "project_not_found"

    assert error_code(
             conn
             |> recycle()
             |> authenticate(identity)
             |> put(~p"/v1/projects/#{missing}/team-access/not-a-uuid", %{access: "reader"})
             |> json_response(404)
           ) == "project_not_found"
  end

  defp membership_fixture(identity) do
    {:ok, membership} =
      Accounts.create_organization_membership(identity.auth_context, %{
        email: "team-api-#{Ecto.UUID.generate()}@example.test",
        display_name: "Team API Member",
        role: "member"
      })

    membership
  end

  defp error_code(response), do: response["error"]["code"]
end
