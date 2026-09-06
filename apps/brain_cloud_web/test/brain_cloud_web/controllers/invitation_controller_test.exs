defmodule BrainCloudWeb.InvitationControllerTest do
  use BrainCloudWeb.ConnCase, async: true

  alias BrainCloud.Accounts
  alias BrainCloud.Accounts.ApiToken
  alias BrainCloud.Accounts.AuditEvent
  alias BrainCloud.Accounts.OrganizationInvitation
  alias BrainCloud.Accounts.OrganizationMembership
  alias BrainCloud.Accounts.User
  alias BrainCloud.Repo

  import Ecto.Query
  import ExUnit.CaptureLog

  test "creates, lists, accepts, and conceals a one-time invitation", %{
    conn: conn,
    identity: identity
  } do
    expires_at = DateTime.add(DateTime.utc_now(:second), 3600, :second)

    captured_log =
      capture_log(fn ->
        response =
          conn
          |> authenticate(identity)
          |> post(~p"/v1/organization/invitations", %{
            email: " Invited@Example.Test ",
            display_name: " Invited Person ",
            scopes: ["memory.read", "search.keyword"],
            expires_at: expires_at,
            role: "owner"
          })
          |> json_response(201)

        send(self(), {:create_response, response})
      end)

    assert_receive {:create_response, create_response}

    assert %{
             "acceptance_token" => acceptance_token,
             "invitation" =>
               %{
                 "id" => invitation_id,
                 "email" => "invited@example.test",
                 "display_name" => "Invited Person",
                 "role" => "member",
                 "scopes" => ["memory.read", "search.keyword"],
                 "status" => "pending",
                 "accepted_at" => nil,
                 "revoked_at" => nil,
                 "accepted_membership_id" => nil,
                 "created_by_membership_id" => created_by_id
               } = invitation_json
           } = create_response

    assert created_by_id == identity.membership.id
    assert Map.keys(invitation_json) |> Enum.sort() == invitation_keys()
    assert acceptance_token =~ ~r/^bci1_[0-9a-f]{32}_[A-Za-z0-9_-]{43}$/

    stored = Repo.get!(OrganizationInvitation, invitation_id)
    refute stored.secret_digest == acceptance_token
    digest = Base.encode16(stored.secret_digest, case: :lower)
    refute captured_log =~ acceptance_token
    refute captured_log =~ digest

    assert %{"invitations" => [listed]} =
             conn
             |> recycle()
             |> authenticate(identity)
             |> get(~p"/v1/organization/invitations")
             |> json_response(200)

    assert listed == invitation_json
    refute inspect(listed) =~ acceptance_token
    refute inspect(listed) =~ digest

    assert %{
             "membership" =>
               %{
                 "id" => membership_id,
                 "email" => "invited@example.test",
                 "display_name" => "Invited Person",
                 "role" => "member",
                 "active" => true
               } = membership,
             "token" =>
               %{
                 "id" => token_id,
                 "name" => "Invitation acceptance",
                 "scopes" => ["memory.read", "search.keyword"],
                 "expires_at" => nil,
                 "bootstrap" => false,
                 "token" => api_token
               } = token
           } =
             conn
             |> recycle()
             |> post(~p"/v1/invitations/accept", %{acceptance_token: acceptance_token})
             |> json_response(201)

    assert Map.keys(membership) |> Enum.sort() == membership_keys()
    assert Map.keys(token) |> Enum.sort() == created_token_keys()
    assert api_token =~ ~r/^bc1_[0-9a-f]{32}_[A-Za-z0-9_-]{43}$/
    assert {:ok, accepted_auth} = Accounts.authenticate(api_token)
    assert accepted_auth.membership_id == membership_id

    accepted = Repo.get!(OrganizationInvitation, invitation_id)
    assert accepted.accepted_membership_id == membership_id
    assert accepted.accepted_at
    assert Repo.get!(ApiToken, token_id)

    refute inspect(BrainCloudWeb.APIJSON.invitation(accepted)) =~ acceptance_token

    assert exact_error(
             conn
             |> recycle()
             |> post(~p"/v1/invitations/accept", %{acceptance_token: acceptance_token})
             |> json_response(404),
             "invitation_not_found",
             "Invitation not found"
           )
  end

  test "returns exact invitation conflicts and validation failures", %{
    conn: conn,
    identity: identity
  } do
    params = %{
      email: "duplicate@example.test",
      display_name: "Duplicate",
      scopes: ["memory.read"],
      expires_at: DateTime.add(DateTime.utc_now(:second), 3600, :second)
    }

    assert %{"acceptance_token" => first_secret} =
             conn
             |> authenticate(identity)
             |> post(~p"/v1/organization/invitations", params)
             |> json_response(201)

    duplicate =
      conn
      |> recycle()
      |> authenticate(identity)
      |> post(~p"/v1/organization/invitations", params)
      |> json_response(409)

    assert exact_error(
             duplicate,
             "invitation_exists",
             "An unresolved invitation already exists"
           )

    refute inspect(duplicate) =~ first_secret

    too_late = DateTime.add(DateTime.utc_now(:second), 8 * 24 * 3600, :second)

    assert %{
             "error" => %{
               "code" => "validation_failed",
               "details" => %{
                 "expires_at" => [_],
                 "scopes" => [_]
               }
             }
           } =
             conn
             |> recycle()
             |> authenticate(identity)
             |> post(~p"/v1/organization/invitations", %{
               email: "invalid@example.test",
               display_name: "Invalid",
               scopes: ["tokens.manage"],
               expires_at: too_late
             })
             |> json_response(422)

    assert {:ok, membership} =
             Accounts.create_organization_membership(identity.auth_context, %{
               email: "member@example.test",
               display_name: "Member",
               role: "member"
             })

    assert membership

    assert exact_error(
             conn
             |> recycle()
             |> authenticate(identity)
             |> post(~p"/v1/organization/invitations", %{params | email: "member@example.test"})
             |> json_response(409),
             "membership_exists",
             "Organization membership already exists"
           )
  end

  test "revoke is concealed, idempotent, and emits only one transition audit", %{
    conn: conn,
    identity: identity
  } do
    assert %{"invitation" => %{"id" => invitation_id}} =
             conn
             |> authenticate(identity)
             |> post(~p"/v1/organization/invitations", invitation_params("revoke@example.test"))
             |> json_response(201)

    assert conn
           |> recycle()
           |> authenticate(identity)
           |> delete(~p"/v1/organization/invitations/#{invitation_id}")
           |> response(204) == ""

    assert conn
           |> recycle()
           |> authenticate(identity)
           |> delete(~p"/v1/organization/invitations/#{invitation_id}")
           |> response(204) == ""

    assert Repo.aggregate(
             from(event in AuditEvent,
               where: event.action == "invitation.revoke" and event.resource_id == ^invitation_id
             ),
             :count
           ) == 1

    other = BrainCloud.DataCase.identity_fixture()

    for id <- [invitation_id, "malformed", Ecto.UUID.generate()] do
      assert exact_error(
               conn
               |> recycle()
               |> authenticate(other)
               |> delete("/v1/organization/invitations/#{id}")
               |> json_response(404),
               "invitation_not_found",
               "Invitation not found"
             )
    end
  end

  test "acceptance conceals every unavailable token class and commits nothing", %{
    conn: conn,
    identity: identity
  } do
    assert %{
             "invitation" => %{"id" => invitation_id},
             "acceptance_token" => acceptance_token
           } =
             conn
             |> authenticate(identity)
             |> post(
               ~p"/v1/organization/invitations",
               invitation_params("unavailable@example.test")
             )
             |> json_response(201)

    invitation = Repo.get!(OrganizationInvitation, invitation_id)

    invitation
    |> Ecto.Changeset.change(expires_at: DateTime.add(DateTime.utc_now(), -1, :second))
    |> Repo.update!()

    replacement = if String.ends_with?(acceptance_token, "A"), do: "B", else: "A"

    wrong_secret =
      String.slice(acceptance_token, 0, byte_size(acceptance_token) - 1) <> replacement

    for token <- [
          nil,
          "bad",
          "bci1_#{String.duplicate("0", 32)}_#{String.duplicate("A", 43)}",
          wrong_secret,
          acceptance_token
        ] do
      params = if token, do: %{acceptance_token: token}, else: %{}

      assert exact_error(
               conn
               |> recycle()
               |> post(~p"/v1/invitations/accept", params)
               |> json_response(404),
               "invitation_not_found",
               "Invitation not found"
             )
    end

    assert Repo.get!(OrganizationInvitation, invitation_id).accepted_at == nil
    assert Repo.get_by(User, email: "unavailable@example.test") == nil
  end

  test "authorization precedes invitation validation and lookup", %{
    conn: conn,
    identity: identity
  } do
    assert {:ok, _token, members_only} =
             Accounts.create_api_token(identity.auth_context, %{
               name: "Members only",
               scopes: ["members.manage"]
             })

    assert exact_error(
             conn
             |> put_req_header("authorization", "Bearer #{members_only}")
             |> post(~p"/v1/organization/invitations", %{})
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
             |> delete(~p"/v1/organization/invitations/#{Ecto.UUID.generate()}")
             |> json_response(403),
             "forbidden",
             "Permission denied"
           )
  end

  defp invitation_params(email) do
    %{
      email: email,
      display_name: "Invited Person",
      scopes: ["memory.read"],
      expires_at: DateTime.add(DateTime.utc_now(:second), 3600, :second)
    }
  end

  defp invitation_keys do
    ~w(accepted_at accepted_membership_id created_by_membership_id display_name email expires_at id inserted_at revoked_at role scopes status updated_at)
  end

  defp membership_keys do
    ~w(active deactivated_at display_name email id inserted_at role updated_at user_id)
  end

  defp created_token_keys do
    ~w(bootstrap expires_at id inserted_at name revoked_at scopes token)
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
