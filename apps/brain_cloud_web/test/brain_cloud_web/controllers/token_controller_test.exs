defmodule BrainCloudWeb.TokenControllerTest do
  use BrainCloudWeb.ConnCase, async: true

  alias BrainCloud.Accounts
  alias BrainCloud.Accounts.ApiToken
  alias BrainCloud.Accounts.OrganizationMembership

  import ExUnit.CaptureLog

  test "creates a scoped token, returns its secret once, lists metadata, and revokes it", %{
    conn: conn,
    identity: identity
  } do
    captured_log =
      capture_log(fn ->
        create_response =
          conn
          |> authenticate(identity)
          |> post(~p"/v1/auth/tokens", %{
            name: "Reader",
            scopes: ["memory.read", "search.keyword"]
          })
          |> json_response(201)

        send(self(), {:create_response, create_response})
      end)

    assert_receive {:create_response, create_response}

    assert %{
             "token" => %{
               "id" => token_id,
               "name" => "Reader",
               "scopes" => ["memory.read", "search.keyword"],
               "token" => raw_token,
               "bootstrap" => false,
               "expires_at" => nil,
               "revoked_at" => nil,
               "inserted_at" => inserted_at
             }
           } = create_response

    assert raw_token =~ ~r/^bc1_[0-9a-f]{32}_[A-Za-z0-9_-]{43}$/
    assert {:ok, _, _} = DateTime.from_iso8601(inserted_at)
    assert {:ok, _auth} = Accounts.authenticate(raw_token)
    stored_token = BrainCloud.Repo.get!(ApiToken, token_id)
    digest = Base.encode16(stored_token.token_digest, case: :lower)
    refute captured_log =~ raw_token
    refute captured_log =~ digest

    list_response =
      conn
      |> recycle()
      |> authenticate(identity)
      |> get(~p"/v1/auth/tokens")
      |> json_response(200)

    assert %{"tokens" => tokens} = list_response
    listed = Enum.find(tokens, &(&1["id"] == token_id))
    assert listed["name"] == "Reader"
    refute Map.has_key?(listed, "token")
    refute Map.has_key?(listed, "token_digest")
    refute inspect(list_response) =~ raw_token

    assert conn
           |> recycle()
           |> authenticate(identity)
           |> delete(~p"/v1/auth/tokens/#{token_id}")
           |> response(204) == ""

    assert {:error, :unauthorized} = Accounts.authenticate(raw_token)
  end

  test "enforces owner role and scope subset", %{conn: conn, identity: identity} do
    assert {:ok, _token, manager_raw} =
             Accounts.create_api_token(identity.auth_context, %{
               name: "Limited manager",
               scopes: ["tokens.manage"]
             })

    assert %{
             "error" => %{
               "code" => "validation_failed",
               "details" => %{
                 "scopes" => ["must be a subset of the current token scopes"]
               }
             }
           } =
             conn
             |> put_req_header("authorization", "Bearer #{manager_raw}")
             |> post(~p"/v1/auth/tokens", %{
               name: "Escalated",
               scopes: ["tokens.manage", "memory.write"]
             })
             |> json_response(422)

    identity.membership
    |> OrganizationMembership.changeset(%{role: "member"})
    |> BrainCloud.Repo.update!()

    assert %{"error" => %{"code" => "forbidden"}} =
             conn
             |> recycle()
             |> authenticate(identity)
             |> get(~p"/v1/auth/tokens")
             |> json_response(403)
  end

  test "conceals tokens belonging to another organization", %{
    conn: conn,
    identity: identity
  } do
    other_identity = BrainCloud.DataCase.identity_fixture()

    assert %{"error" => %{"code" => "token_not_found"}} =
             conn
             |> authenticate(identity)
             |> delete(~p"/v1/auth/tokens/#{other_identity.token.id}")
             |> json_response(404)
  end
end
