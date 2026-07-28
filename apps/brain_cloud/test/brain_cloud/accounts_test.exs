defmodule BrainCloud.AccountsTest do
  use BrainCloud.DataCase, async: true

  alias BrainCloud.Accounts
  alias BrainCloud.Accounts.ApiToken
  alias BrainCloud.Accounts.AuditEvent
  alias BrainCloud.Accounts.Organization
  alias BrainCloud.Accounts.OrganizationMembership
  alias BrainCloud.Accounts.User

  test "bootstraps an owner idempotently and rotates only by explicit recovery" do
    attrs = %{
      email: " OWNER@Example.Test ",
      display_name: " Owner ",
      organization_name: "Example",
      organization_slug: " Example "
    }

    assert {:ok, first} = Accounts.bootstrap_owner(attrs)
    assert first.created
    assert first.raw_token =~ ~r/^bc1_[0-9a-f]{32}_/
    assert first.user.email == "owner@example.test"
    assert first.user.display_name == "Owner"
    assert first.organization.slug == "example"
    assert first.membership.role == "owner"

    assert {:ok, auth} = Accounts.authenticate(first.raw_token)
    assert auth.user_id == first.user.id
    assert auth.organization_id == first.organization.id
    assert "tokens.manage" in auth.scopes

    assert {:ok, repeated} = Accounts.bootstrap_owner(attrs)
    refute repeated.created
    assert repeated.raw_token == nil
    assert repeated.token.id == first.token.id

    assert {:ok, rotated} = Accounts.bootstrap_owner(attrs, rotate_token: true)
    assert rotated.created
    assert rotated.raw_token != first.raw_token
    assert {:error, :unauthorized} = Accounts.authenticate(first.raw_token)
    assert {:ok, _auth} = Accounts.authenticate(rotated.raw_token)

    assert Repo.aggregate(AuditEvent, :count, :id) == 3
  end

  test "creates, lists, expires, and revokes scoped organization tokens" do
    identity = identity_fixture()
    auth = identity.auth_context

    assert {:ok, token, raw_token} =
             Accounts.create_api_token(auth, %{
               name: "Read only",
               scopes: ["memory.read", "search.keyword"]
             })

    assert token.token_digest != raw_token
    digest = Base.encode16(token.token_digest, case: :lower)
    refute inspect(token) =~ digest
    refute inspect(token) =~ "token_digest"
    assert {:ok, token_auth} = Accounts.authenticate(raw_token)
    assert token_auth.organization_id == auth.organization_id
    assert token_auth.scopes == ["memory.read", "search.keyword"]

    assert {:ok, tokens} = Accounts.list_api_tokens(auth)

    assert Enum.map(tokens, & &1.id) |> Enum.sort() ==
             Enum.sort([identity.token.id, token.id])

    assert {:error, :forbidden} =
             Accounts.create_api_token(token_auth, %{
               name: "Escalated",
               scopes: ["tokens.manage"]
             })

    assert {:ok, manager_token, manager_raw} =
             Accounts.create_api_token(auth, %{
               name: "Limited manager",
               scopes: ["tokens.manage"]
             })

    assert {:ok, manager_auth} = Accounts.authenticate(manager_raw)

    assert {:error, changeset} =
             Accounts.create_api_token(manager_auth, %{
               name: "Escalated",
               scopes: ["tokens.manage", "memory.write"]
             })

    assert "must be a subset of the current token scopes" in errors_on(changeset).scopes

    assert manager_token.scopes == ["tokens.manage"]
    assert {:ok, _revoked} = Accounts.revoke_api_token(auth, token.id)
    assert {:error, :unauthorized} = Accounts.authenticate(raw_token)

    expired_at = DateTime.add(DateTime.utc_now(), -60, :second)

    assert {:ok, _expired, expired_raw} =
             Accounts.create_api_token(auth, %{
               name: "Expired",
               scopes: ["memory.read"],
               expires_at: expired_at
             })

    assert {:error, :unauthorized} = Accounts.authenticate(expired_raw)

    audit_metadata =
      AuditEvent
      |> Repo.all()
      |> Enum.map(& &1.metadata)
      |> inspect()

    refute audit_metadata =~ raw_token
    refute audit_metadata =~ digest
  end

  test "inactive memberships and cross-organization token ids are rejected" do
    identity = identity_fixture()
    other_identity = identity_fixture()

    assert {:ok, token, raw_token} =
             Accounts.create_api_token(identity.auth_context, %{
               name: "Member token",
               scopes: ["memory.read"]
             })

    identity.membership
    |> Ecto.Changeset.change(deactivated_at: DateTime.utc_now(:microsecond))
    |> Repo.update!()

    assert {:error, :unauthorized} = Accounts.authenticate(raw_token)

    assert {:error, :token_not_found} =
             Accounts.revoke_api_token(other_identity.auth_context, token.id)
  end

  test "adopts the deterministic Phase 1 compatibility organization" do
    phase_one = Repo.get!(Organization, Accounts.phase_one_organization_id())

    assert phase_one.slug == "phase-1-import"

    assert {:ok, adopted} =
             Accounts.bootstrap_owner(
               %{email: "legacy-owner@example.test", display_name: "Legacy Owner"},
               adopt_phase_one: true
             )

    assert adopted.organization.id == phase_one.id
    assert Repo.get!(User, adopted.user.id)
    assert Repo.get!(OrganizationMembership, adopted.membership.id).role == "owner"
  end

  test "validates bootstrap identity fields" do
    assert {:error, changeset} =
             Accounts.bootstrap_owner(%{
               email: "invalid",
               display_name: "",
               organization_name: "",
               organization_slug: "Invalid Slug"
             })

    assert errors_on(changeset).email
    assert errors_on(changeset).display_name

    assert Repo.aggregate(User, :count, :id) == 0
    assert Repo.aggregate(ApiToken, :count, :id) == 0
  end
end
