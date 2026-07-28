defmodule BrainCloudWeb.ProjectControllerTest do
  use BrainCloudWeb.ConnCase, async: true

  alias BrainCloud.Accounts
  alias BrainCloud.Accounts.OrganizationMembership

  test "requires a valid persisted bearer token" do
    expected = %{
      "error" => %{
        "code" => "unauthorized",
        "message" => "Authentication required",
        "details" => %{}
      }
    }

    requests = [
      fn request_conn -> post(request_conn, ~p"/v1/projects", %{name: "Research"}) end,
      fn request_conn ->
        post(request_conn, ~p"/v1/projects/#{Ecto.UUID.generate()}/memories", %{})
      end,
      fn request_conn ->
        get(
          request_conn,
          ~p"/v1/projects/#{Ecto.UUID.generate()}/memories/#{Ecto.UUID.generate()}"
        )
      end,
      fn request_conn ->
        get(request_conn, ~p"/v1/projects/#{Ecto.UUID.generate()}/search?q=x")
      end
    ]

    Enum.each(requests, fn request ->
      assert request.(build_conn()) |> json_response(401) == expected

      assert build_conn()
             |> put_req_header("authorization", "Basic malformed")
             |> request.()
             |> json_response(401) == expected

      assert build_conn()
             |> put_req_header("authorization", "Bearer wrong")
             |> request.()
             |> json_response(401) == expected
    end)
  end

  test "creates a project inside the authenticated organization", %{
    conn: conn,
    identity: identity
  } do
    response =
      conn
      |> authenticate(identity)
      |> post(~p"/v1/projects", %{name: "  Research  "})
      |> json_response(201)

    assert %{
             "project" => %{
               "id" => project_id,
               "organization_id" => organization_id,
               "name" => "Research",
               "creator_actor_id" => creator_actor_id,
               "inserted_at" => inserted_at,
               "updated_at" => updated_at
             }
           } = response

    assert organization_id == identity.organization.id
    assert creator_actor_id == identity.user.id
    assert {:ok, _uuid} = Ecto.UUID.cast(project_id)
    assert {:ok, _, _} = DateTime.from_iso8601(inserted_at)
    assert {:ok, _, _} = DateTime.from_iso8601(updated_at)
  end

  test "rejects every invalid persisted-token state with the exact unauthorized response", %{
    identity: identity
  } do
    expected = %{
      "error" => %{
        "code" => "unauthorized",
        "message" => "Authentication required",
        "details" => %{}
      }
    }

    unknown = "bc1_#{String.duplicate("a", 32)}_#{String.duplicate("b", 43)}"
    replacement = if String.last(identity.raw_token) == "x", do: "y", else: "x"

    mismatched =
      String.replace_suffix(identity.raw_token, String.last(identity.raw_token), replacement)

    assert {:ok, _expired, expired} =
             Accounts.create_api_token(identity.auth_context, %{
               name: "Expired",
               scopes: ["projects.create"],
               expires_at: DateTime.add(DateTime.utc_now(), -60, :second)
             })

    assert {:ok, revoked_token, revoked} =
             Accounts.create_api_token(identity.auth_context, %{
               name: "Revoked",
               scopes: ["projects.create"]
             })

    assert {:ok, _token} =
             Accounts.revoke_api_token(identity.auth_context, revoked_token.id)

    for raw_token <- ["malformed", unknown, mismatched, expired, revoked] do
      assert build_conn()
             |> put_req_header("authorization", "Bearer #{raw_token}")
             |> post(~p"/v1/projects", %{name: "Denied"})
             |> json_response(401) == expected
    end

    identity.membership
    |> OrganizationMembership.changeset(%{deactivated_at: DateTime.utc_now(:microsecond)})
    |> BrainCloud.Repo.update!()

    assert build_conn()
           |> authenticate(identity)
           |> post(~p"/v1/projects", %{name: "Denied"})
           |> json_response(401) == expected
  end

  test "rejects insufficient scope before resource handling", %{
    conn: conn,
    identity: identity
  } do
    assert {:ok, _token, raw_token} =
             Accounts.create_api_token(identity.auth_context, %{
               name: "Read only",
               scopes: ["memory.read"]
             })

    assert %{
             "error" => %{
               "code" => "forbidden",
               "message" => "Permission denied",
               "details" => %{}
             }
           } =
             conn
             |> put_req_header("authorization", "Bearer #{raw_token}")
             |> post(~p"/v1/projects", %{name: "Research"})
             |> json_response(403)
  end

  test "returns structured validation errors", %{conn: conn, identity: identity} do
    assert %{
             "error" => %{
               "code" => "validation_failed",
               "message" => "Request validation failed",
               "details" => %{"name" => [_message]}
             }
           } =
             conn
             |> authenticate(identity)
             |> post(~p"/v1/projects", %{name: " "})
             |> json_response(422)
  end
end
