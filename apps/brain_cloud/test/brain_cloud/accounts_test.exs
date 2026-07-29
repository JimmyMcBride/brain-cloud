defmodule BrainCloud.AccountsTest do
  use BrainCloud.DataCase, async: false

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

  test "creates, lists, and deterministically rejects duplicate memberships" do
    identity = identity_fixture()
    other_identity = identity_fixture()
    user_count = Repo.aggregate(User, :count, :id)

    assert {:error, invalid_role_changeset} =
             Accounts.create_organization_membership(identity.auth_context, %{
               email: "rolled-back@example.test",
               display_name: "Rolled Back",
               role: "administrator"
             })

    assert errors_on(invalid_role_changeset).role
    assert Repo.aggregate(User, :count, :id) == user_count

    attrs = %{
      email: " MEMBER@Example.Test ",
      display_name: " First Profile ",
      role: "member"
    }

    assert {:ok, membership} =
             Accounts.create_organization_membership(identity.auth_context, attrs)

    assert membership.user.email == "member@example.test"
    assert membership.user.display_name == "First Profile"
    assert membership.role == "member"
    assert membership.deactivated_at == nil

    assert {:ok, memberships} =
             Accounts.list_organization_memberships(identity.auth_context)

    assert Enum.map(memberships, & &1.id) |> Enum.sort() ==
             Enum.sort([identity.membership.id, membership.id])

    assert {:error, :membership_exists} =
             Accounts.create_organization_membership(identity.auth_context, attrs)

    assert {:ok, other_membership} =
             Accounts.create_organization_membership(other_identity.auth_context, %{
               attrs
               | display_name: "Ignored Replacement"
             })

    assert other_membership.user.id == membership.user.id
    assert other_membership.user.display_name == "First Profile"
    assert Repo.aggregate(User, :count, :id) == 3

    assert {:ok, _deactivated} =
             Accounts.deactivate_organization_membership(
               identity.auth_context,
               membership.id
             )

    assert {:error, :membership_inactive} =
             Accounts.create_organization_membership(identity.auth_context, attrs)
  end

  test "changes roles, suspends access, reactivates without restoring credentials, and audits" do
    identity = identity_fixture()
    membership = membership_fixture(identity, role: "owner")

    assert {:ok, _token, first_raw_token} =
             Accounts.create_membership_api_token(
               identity.auth_context,
               membership.id,
               %{name: "Second owner", scopes: ["members.manage", "tokens.manage"]}
             )

    assert {:ok, second_owner_auth} = Accounts.authenticate(first_raw_token)

    assert {:ok, demoted} =
             Accounts.update_organization_membership_role(
               identity.auth_context,
               membership.id,
               "member"
             )

    assert demoted.role == "member"
    assert {:error, :unauthorized} = Accounts.authenticate(first_raw_token)

    assert {:ok, promoted} =
             Accounts.update_organization_membership_role(
               identity.auth_context,
               membership.id,
               "owner"
             )

    assert promoted.role == "owner"

    assert {:ok, _token, replacement_raw_token} =
             Accounts.create_membership_api_token(
               identity.auth_context,
               membership.id,
               %{name: "Replacement owner", scopes: ["members.manage", "tokens.manage"]}
             )

    assert {:ok, _auth} = Accounts.authenticate(replacement_raw_token)

    assert {:ok, deactivated} =
             Accounts.deactivate_organization_membership(
               identity.auth_context,
               membership.id
             )

    assert deactivated.deactivated_at
    assert {:error, :unauthorized} = Accounts.authenticate(replacement_raw_token)

    assert {:ok, reactivated} =
             Accounts.reactivate_organization_membership(
               identity.auth_context,
               membership.id
             )

    assert reactivated.deactivated_at == nil
    assert {:error, :unauthorized} = Accounts.authenticate(first_raw_token)
    assert {:error, :unauthorized} = Accounts.authenticate(replacement_raw_token)

    actions =
      AuditEvent
      |> where([event], event.resource_id == ^membership.id)
      |> order_by([event], asc: event.inserted_at)
      |> Repo.all()
      |> Enum.map(& &1.action)

    assert actions == [
             "membership.create",
             "membership.role_change",
             "membership.role_change",
             "membership.deactivate",
             "membership.reactivate"
           ]

    refute inspect(Repo.all(AuditEvent)) =~ first_raw_token
    refute inspect(Repo.all(AuditEvent)) =~ replacement_raw_token
    assert second_owner_auth.membership_id == membership.id
  end

  test "target-member tokens enforce caller subsets and reject member management scopes" do
    identity = identity_fixture()
    membership = membership_fixture(identity, role: "member")

    assert {:error, changeset} =
             Accounts.create_membership_api_token(
               identity.auth_context,
               membership.id,
               %{
                 name: "Invalid manager",
                 scopes: ["members.manage", "projects.manage_access", "teams.manage"]
               }
             )

    assert "cannot include management scopes for a member" in errors_on(changeset).scopes

    assert {:ok, token, raw_token} =
             Accounts.create_membership_api_token(
               identity.auth_context,
               membership.id,
               %{name: "Member reader", scopes: ["memory.read"]}
             )

    assert token.membership_id == membership.id
    assert {:ok, auth} = Accounts.authenticate(raw_token)
    assert auth.membership_id == membership.id
    assert auth.scopes == ["memory.read"]

    assert {:ok, _manager_token, limited_manager_raw} =
             Accounts.create_api_token(identity.auth_context, %{
               name: "Membership manager",
               scopes: ["members.manage", "tokens.manage"]
             })

    assert {:ok, limited_manager_auth} = Accounts.authenticate(limited_manager_raw)

    assert {:error, changeset} =
             Accounts.create_membership_api_token(
               limited_manager_auth,
               membership.id,
               %{name: "Escalated reader", scopes: ["memory.read"]}
             )

    assert "must be a subset of the current token scopes" in errors_on(changeset).scopes
  end

  test "conceals cross-organization memberships and preserves the final active owner" do
    identity = identity_fixture()
    other_identity = identity_fixture()
    audit_count = Repo.aggregate(AuditEvent, :count, :id)

    assert {:error, :membership_not_found} =
             Accounts.update_organization_membership_role(
               identity.auth_context,
               other_identity.membership.id,
               "member"
             )

    assert {:error, :membership_not_found} =
             Accounts.deactivate_organization_membership(
               identity.auth_context,
               other_identity.membership.id
             )

    assert {:error, :last_owner_required} =
             Accounts.update_organization_membership_role(
               identity.auth_context,
               identity.membership.id,
               "member"
             )

    assert {:error, :last_owner_required} =
             Accounts.deactivate_organization_membership(
               identity.auth_context,
               identity.membership.id
             )

    assert Repo.aggregate(AuditEvent, :count, :id) == audit_count
  end

  test "concurrent owner removals leave one active owner" do
    identity = identity_fixture()
    second_membership = membership_fixture(identity, role: "owner")

    assert {:ok, _token, second_owner_raw} =
             Accounts.create_membership_api_token(
               identity.auth_context,
               second_membership.id,
               %{name: "Concurrent owner", scopes: ["members.manage", "tokens.manage"]}
             )

    assert {:ok, second_owner_auth} = Accounts.authenticate(second_owner_raw)

    operations = [
      fn ->
        Accounts.deactivate_organization_membership(
          identity.auth_context,
          second_membership.id
        )
      end,
      fn ->
        Accounts.deactivate_organization_membership(
          second_owner_auth,
          identity.membership.id
        )
      end
    ]

    results =
      operations
      |> Enum.map(&Task.async/1)
      |> Enum.map(&Task.await(&1, 5_000))

    assert Enum.count(results, &match?({:ok, _membership}, &1)) == 1
    assert Enum.count(results, &(&1 == {:error, :last_owner_required})) == 1

    assert Repo.aggregate(
             from(membership in OrganizationMembership,
               where:
                 membership.organization_id == ^identity.organization.id and
                   membership.role == "owner" and is_nil(membership.deactivated_at)
             ),
             :count,
             :id
           ) == 1
  end

  defp membership_fixture(identity, overrides) do
    suffix = Ecto.UUID.generate()

    attrs =
      overrides
      |> Map.new()
      |> Map.merge(%{
        email: "member-#{suffix}@example.test",
        display_name: "Test Member",
        role: Keyword.fetch!(overrides, :role)
      })

    {:ok, membership} =
      Accounts.create_organization_membership(identity.auth_context, attrs)

    membership
  end
end
