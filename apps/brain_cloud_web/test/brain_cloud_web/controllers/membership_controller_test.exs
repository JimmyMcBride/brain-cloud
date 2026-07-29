defmodule BrainCloudWeb.MembershipControllerTest do
  use BrainCloudWeb.ConnCase, async: true

  alias BrainCloud.Accounts
  alias BrainCloud.Accounts.ApiToken
  alias BrainCloud.Accounts.AuditEvent
  alias BrainCloud.Accounts.OrganizationMembership
  alias BrainCloud.Repo

  import Ecto.Query
  import ExUnit.CaptureLog

  test "administers a membership and never restores suspended credentials", %{
    conn: conn,
    identity: identity
  } do
    create_response =
      conn
      |> authenticate(identity)
      |> post(~p"/v1/organization/memberships", %{
        email: " New-Member@Example.Test ",
        display_name: " New Member ",
        role: "member"
      })
      |> json_response(201)

    assert %{
             "membership" => %{
               "id" => membership_id,
               "user_id" => user_id,
               "email" => "new-member@example.test",
               "display_name" => "New Member",
               "role" => "member",
               "active" => true,
               "deactivated_at" => nil,
               "inserted_at" => inserted_at,
               "updated_at" => updated_at
             }
           } = create_response

    assert Ecto.UUID.cast(user_id) != :error
    assert {:ok, _, _} = DateTime.from_iso8601(inserted_at)
    assert {:ok, _, _} = DateTime.from_iso8601(updated_at)

    list_response =
      conn
      |> recycle()
      |> authenticate(identity)
      |> get(~p"/v1/organization/memberships")
      |> json_response(200)

    assert Enum.any?(list_response["memberships"], &(&1["id"] == membership_id))

    assert %{"membership" => %{"role" => "owner"}} =
             conn
             |> recycle()
             |> authenticate(identity)
             |> patch(~p"/v1/organization/memberships/#{membership_id}", %{role: "owner"})
             |> json_response(200)

    captured_log =
      capture_log(fn ->
        response =
          conn
          |> recycle()
          |> authenticate(identity)
          |> post(~p"/v1/organization/memberships/#{membership_id}/tokens", %{
            name: "Second owner",
            scopes: ["members.manage", "tokens.manage"]
          })
          |> json_response(201)

        send(self(), {:token_response, response})
      end)

    assert_receive {:token_response, token_response}
    assert %{"token" => %{"id" => token_id, "token" => raw_token}} = token_response
    stored_token = Repo.get!(ApiToken, token_id)
    digest = Base.encode16(stored_token.token_digest, case: :lower)
    refute captured_log =~ raw_token
    refute captured_log =~ digest

    assert conn
           |> recycle()
           |> authenticate(identity)
           |> delete(~p"/v1/organization/memberships/#{membership_id}")
           |> response(204) == ""

    assert {:error, :unauthorized} = Accounts.authenticate(raw_token)

    assert %{"membership" => %{"active" => true, "deactivated_at" => nil}} =
             conn
             |> recycle()
             |> authenticate(identity)
             |> post(~p"/v1/organization/memberships/#{membership_id}/reactivate")
             |> json_response(200)

    assert {:error, :unauthorized} = Accounts.authenticate(raw_token)

    audit_metadata =
      AuditEvent
      |> where([event], event.resource_id == ^Ecto.UUID.cast!(membership_id))
      |> Repo.all()
      |> inspect()

    refute audit_metadata =~ raw_token
    refute audit_metadata =~ digest
  end

  test "returns deterministic membership conflicts and validation errors", %{
    conn: conn,
    identity: identity
  } do
    params = %{
      email: "duplicate@example.test",
      display_name: "Duplicate",
      role: "member"
    }

    assert %{"membership" => %{"id" => membership_id}} =
             conn
             |> authenticate(identity)
             |> post(~p"/v1/organization/memberships", params)
             |> json_response(201)

    assert exact_error(
             conn
             |> recycle()
             |> authenticate(identity)
             |> post(~p"/v1/organization/memberships", params)
             |> json_response(409),
             "membership_exists",
             "Organization membership already exists"
           )

    assert conn
           |> recycle()
           |> authenticate(identity)
           |> delete(~p"/v1/organization/memberships/#{membership_id}")
           |> response(204) == ""

    assert exact_error(
             conn
             |> recycle()
             |> authenticate(identity)
             |> post(~p"/v1/organization/memberships", params)
             |> json_response(409),
             "membership_inactive",
             "Organization membership is inactive"
           )

    assert %{
             "error" => %{
               "code" => "validation_failed",
               "details" => %{"role" => ["can't be blank"]}
             }
           } =
             conn
             |> recycle()
             |> authenticate(identity)
             |> patch(~p"/v1/organization/memberships/#{membership_id}", %{})
             |> json_response(422)
  end

  test "enforces authorization before lookup and conceals other organizations", %{
    conn: conn,
    identity: identity
  } do
    other_identity = BrainCloud.DataCase.identity_fixture()
    unknown_id = Ecto.UUID.generate()

    assert {:ok, _token, members_only_raw} =
             Accounts.create_api_token(identity.auth_context, %{
               name: "Members only",
               scopes: ["members.manage"]
             })

    assert exact_error(
             conn
             |> put_req_header("authorization", "Bearer #{members_only_raw}")
             |> post(~p"/v1/organization/memberships/#{unknown_id}/tokens", %{
               name: "Denied",
               scopes: []
             })
             |> json_response(403),
             "forbidden",
             "Permission denied"
           )

    identity.membership
    |> OrganizationMembership.changeset(%{role: "member"})
    |> Repo.update!()

    assert exact_error(
             conn
             |> recycle()
             |> authenticate(identity)
             |> patch(~p"/v1/organization/memberships/#{unknown_id}", %{role: "member"})
             |> json_response(403),
             "forbidden",
             "Permission denied"
           )

    other_identity.membership
    |> OrganizationMembership.changeset(%{role: "owner"})
    |> Repo.update!()

    assert exact_error(
             conn
             |> recycle()
             |> authenticate(other_identity)
             |> patch(~p"/v1/organization/memberships/#{unknown_id}", %{role: "member"})
             |> json_response(404),
             "membership_not_found",
             "Organization membership not found"
           )

    assert exact_error(
             conn
             |> recycle()
             |> authenticate(other_identity)
             |> patch(~p"/v1/organization/memberships/#{identity.membership.id}", %{
               role: "member"
             })
             |> json_response(404),
             "membership_not_found",
             "Organization membership not found"
           )
  end

  test "protects the final owner and limits member credential scopes", %{
    conn: conn,
    identity: identity
  } do
    assert %{
             "error" => %{
               "code" => "validation_failed",
               "details" => %{"role" => ["can't be blank"]}
             }
           } =
             conn
             |> authenticate(identity)
             |> patch(~p"/v1/organization/memberships/#{identity.membership.id}", %{})
             |> json_response(422)

    assert exact_error(
             conn
             |> recycle()
             |> authenticate(identity)
             |> patch(~p"/v1/organization/memberships/#{identity.membership.id}", %{
               role: "member"
             })
             |> json_response(409),
             "last_owner_required",
             "At least one active owner is required"
           )

    assert %{"membership" => %{"id" => member_id}} =
             conn
             |> recycle()
             |> authenticate(identity)
             |> post(~p"/v1/organization/memberships", %{
               email: "reader@example.test",
               display_name: "Reader",
               role: "member"
             })
             |> json_response(201)

    assert %{
             "error" => %{
               "code" => "validation_failed",
               "details" => %{
                 "scopes" => ["cannot include management scopes for a member"]
               }
             }
           } =
             conn
             |> recycle()
             |> authenticate(identity)
             |> post(~p"/v1/organization/memberships/#{member_id}/tokens", %{
               name: "Invalid manager",
               scopes: ["members.manage"]
             })
             |> json_response(422)

    assert %{"token" => %{"token" => raw_token, "scopes" => ["memory.read"]}} =
             conn
             |> recycle()
             |> authenticate(identity)
             |> post(~p"/v1/organization/memberships/#{member_id}/tokens", %{
               name: "Reader",
               scopes: ["memory.read"]
             })
             |> json_response(201)

    assert {:ok, member_auth} = Accounts.authenticate(raw_token)
    assert member_auth.membership_id == Ecto.UUID.cast!(member_id)
  end

  defp exact_error(response, code, message) do
    response == %{
      "error" => %{
        "code" => code,
        "message" => message,
        "details" => %{}
      }
    }
  end
end
