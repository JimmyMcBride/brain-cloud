defmodule BrainCloud.OrganizationInvitationTest do
  use BrainCloud.DataCase, async: false

  alias BrainCloud.Accounts
  alias BrainCloud.Accounts.ApiToken
  alias BrainCloud.Accounts.AuditEvent
  alias BrainCloud.Accounts.OrganizationInvitation
  alias BrainCloud.Accounts.User

  test "browser admission issues no credential, session, or email verification" do
    identity = identity_fixture()
    {:ok, invitation, raw_token} = create_invitation(identity, "browser@example.test")
    token_count = Repo.aggregate(ApiToken, :count)
    session_count = Repo.aggregate(BrainCloud.Accounts.BrowserSession, :count)
    event_count = Repo.aggregate(AuditEvent, :count)

    assert {:ok, result} = Accounts.accept_browser_invitation(raw_token)
    assert Enum.sort(Map.keys(result)) == [:invitation, :membership]
    assert result.membership.organization_id == identity.organization.id
    assert result.membership.role == "member"
    assert result.membership.user.email_verified_at == nil
    assert Repo.aggregate(ApiToken, :count) == token_count
    assert Repo.aggregate(BrainCloud.Accounts.BrowserSession, :count) == session_count
    assert Repo.aggregate(AuditEvent, :count) == event_count + 1

    event = Repo.get_by!(AuditEvent, action: "invitation.accept", resource_id: invitation.id)
    assert event.actor_user_id == result.membership.user_id
    assert event.api_token_id == nil

    assert event.metadata == %{
             "accepted_membership_id" => result.membership.id,
             "acceptance_method" => "browser_invitation"
           }

    assert {:error, :invitation_not_found} = Accounts.accept_browser_invitation(raw_token)
    assert {:error, :invitation_not_found} = Accounts.accept_organization_invitation(raw_token)
  end

  test "browser admission preserves an existing profile and conceals invalid invitations" do
    owner = identity_fixture()

    existing =
      identity_fixture(%{email: "browser-existing@example.test", display_name: "Original"})

    {:ok, _invitation, token} = create_invitation(owner, existing.user.email)
    assert {:ok, result} = Accounts.accept_browser_invitation(token)
    assert result.membership.user_id == existing.user.id
    assert result.membership.user.display_name == "Original"
    assert result.membership.user.email_verified_at == existing.user.email_verified_at

    for invalid <- [nil, "", "invalid", token] do
      assert {:error, :invitation_not_found} = Accounts.accept_browser_invitation(invalid)
    end

    {:ok, revoked, revoked_token} = create_invitation(owner, "revoked-browser@example.test")
    {:ok, :ok} = Accounts.revoke_organization_invitation(owner.auth_context, revoked.id)
    assert {:error, :invitation_not_found} = Accounts.accept_browser_invitation(revoked_token)
  end

  test "creates a normalized invitation with a digest and exact safe audits" do
    identity = identity_fixture()
    expires_at = DateTime.add(DateTime.utc_now(:second), 3600, :second)

    assert {:ok, invitation, raw_token} =
             Accounts.create_organization_invitation(identity.auth_context, %{
               email: " Invitee@Example.Test ",
               display_name: " Invitee ",
               scopes: ["memory.read", "search.keyword", "memory.read"],
               expires_at: expires_at
             })

    assert invitation.email == "invitee@example.test"
    assert invitation.display_name == "Invitee"
    assert invitation.role == "member"
    assert invitation.scopes == ["memory.read", "search.keyword"]
    assert OrganizationInvitation.status(invitation) == "pending"
    assert raw_token =~ ~r/^bci1_[0-9a-f]{32}_[A-Za-z0-9_-]{43}$/
    assert invitation.secret_digest == :crypto.hash(:sha256, raw_token)
    refute inspect(invitation) =~ Base.encode16(invitation.secret_digest, case: :lower)

    event = Repo.get_by!(AuditEvent, action: "invitation.create", resource_id: invitation.id)
    assert event.actor_user_id == identity.user.id
    assert event.api_token_id == identity.token.id
    assert event.resource_type == "organization_invitation"

    assert event.metadata == %{
             "scopes" => ["memory.read", "search.keyword"],
             "expires_at" => DateTime.to_iso8601(invitation.expires_at)
           }

    refute inspect(event.metadata) =~ "invitee@example.test"
    refute inspect(event.metadata) =~ raw_token
  end

  test "validates expiry and member-safe scope boundaries before persistence" do
    identity = identity_fixture()

    assert {:error, changeset} =
             Accounts.create_organization_invitation(identity.auth_context, %{
               email: "invalid@example.test",
               display_name: "Invalid",
               scopes: ["members.manage", "memory.read"],
               expires_at: DateTime.add(DateTime.utc_now(), -1, :second)
             })

    assert "cannot include management scopes for a member" in errors_on(changeset).scopes
    assert "must be in the future" in errors_on(changeset).expires_at
    assert Repo.aggregate(OrganizationInvitation, :count, :id) == 0

    assert {:ok, _token, limited_raw} =
             Accounts.create_api_token(identity.auth_context, %{
               name: "Limited inviter",
               scopes: ["members.manage", "tokens.manage", "memory.read"]
             })

    assert {:ok, limited_auth} = Accounts.authenticate(limited_raw)

    assert {:error, limited_changeset} =
             Accounts.create_organization_invitation(limited_auth, %{
               email: "limited@example.test",
               display_name: "Limited",
               scopes: ["memory.write"],
               expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
             })

    assert "must be a subset of the current token scopes" in errors_on(limited_changeset).scopes
  end

  test "acceptance preserves an existing global user and commits one composite audit" do
    target_organization = identity_fixture()

    existing_identity =
      identity_fixture(%{email: "existing@example.test", display_name: "Original"})

    assert {:ok, invitation, raw_invitation} =
             Accounts.create_organization_invitation(target_organization.auth_context, %{
               email: " EXISTING@example.test ",
               display_name: "Replacement",
               scopes: ["memory.read", "search.keyword"],
               expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
             })

    event_count = Repo.aggregate(AuditEvent, :count, :id)

    assert {:ok, result} = Accounts.accept_organization_invitation(raw_invitation)
    assert result.membership.user_id == existing_identity.user.id
    assert result.membership.organization_id == target_organization.organization.id
    assert result.membership.role == "member"
    assert result.membership.deactivated_at == nil
    assert result.membership.user.display_name == "Original"
    assert Repo.get!(User, existing_identity.user.id).display_name == "Original"
    assert result.token.name == "Invitation acceptance"
    assert result.token.scopes == ["memory.read", "search.keyword"]
    assert result.token.expires_at == nil
    refute result.token.bootstrap
    assert {:ok, auth} = Accounts.authenticate(result.raw_token)
    assert auth.membership_id == result.membership.id

    accepted = Repo.get!(OrganizationInvitation, invitation.id)
    assert accepted.accepted_membership_id == result.membership.id
    assert accepted.accepted_at
    assert OrganizationInvitation.status(accepted) == "accepted"
    assert Repo.aggregate(AuditEvent, :count, :id) == event_count + 1

    event = Repo.get_by!(AuditEvent, action: "invitation.accept", resource_id: invitation.id)
    assert event.actor_user_id == existing_identity.user.id
    assert event.api_token_id == result.token.id

    assert event.metadata == %{
             "accepted_membership_id" => result.membership.id,
             "issued_token_id" => result.token.id,
             "scopes" => ["memory.read", "search.keyword"]
           }

    assert {:error, :invitation_not_found} =
             Accounts.accept_organization_invitation(raw_invitation)
  end

  test "existing active or inactive membership blocks acceptance without partial effects" do
    identity = identity_fixture()

    for deactivated? <- [false, true] do
      email = "existing-#{deactivated?}@example.test"

      assert {:ok, invitation, raw_token} =
               Accounts.create_organization_invitation(identity.auth_context, %{
                 email: email,
                 display_name: "Existing",
                 scopes: ["memory.read"],
                 expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
               })

      assert {:ok, membership} =
               Accounts.create_organization_membership(identity.auth_context, %{
                 email: email,
                 display_name: "Existing",
                 role: "member"
               })

      if deactivated? do
        membership
        |> Ecto.Changeset.change(deactivated_at: DateTime.utc_now(:microsecond))
        |> Repo.update!()
      end

      token_count = Repo.aggregate(ApiToken, :count, :id)
      audit_count = Repo.aggregate(AuditEvent, :count, :id)

      assert {:error, :membership_exists} = Accounts.accept_organization_invitation(raw_token)
      assert {:error, :membership_exists} = Accounts.accept_browser_invitation(raw_token)
      assert Repo.aggregate(ApiToken, :count, :id) == token_count
      assert Repo.aggregate(AuditEvent, :count, :id) == audit_count
      assert Repo.get!(OrganizationInvitation, invitation.id).accepted_at == nil

      invitation
      |> Ecto.Changeset.change(revoked_at: DateTime.utc_now(:microsecond))
      |> Repo.update!()
    end
  end

  test "revoke marks pending and expired invitations once and never changes accepted state" do
    identity = identity_fixture()

    assert {:ok, pending, _raw_token} =
             create_invitation(identity, "pending@example.test")

    assert {:ok, :ok} =
             Accounts.revoke_organization_invitation(identity.auth_context, pending.id)

    assert {:ok, :ok} =
             Accounts.revoke_organization_invitation(identity.auth_context, pending.id)

    revoked = Repo.get!(OrganizationInvitation, pending.id)
    assert OrganizationInvitation.status(revoked) == "revoked"

    assert Repo.aggregate(
             from(event in AuditEvent,
               where: event.action == "invitation.revoke" and event.resource_id == ^pending.id
             ),
             :count
           ) == 1

    assert {:ok, accepted, accepted_raw} =
             create_invitation(identity, "accepted@example.test")

    assert {:ok, _result} = Accounts.accept_organization_invitation(accepted_raw)

    assert {:ok, :ok} =
             Accounts.revoke_organization_invitation(identity.auth_context, accepted.id)

    accepted_after = Repo.get!(OrganizationInvitation, accepted.id)
    assert accepted_after.accepted_at
    assert accepted_after.revoked_at == nil
  end

  test "database constraints reject duplicate unresolved email and cross-tenant provenance" do
    first = identity_fixture()
    second = identity_fixture()
    attrs = raw_invitation_attrs(first, "raw@example.test")

    Repo.insert!(struct!(OrganizationInvitation, attrs))

    assert_raise Ecto.ConstraintError, ~r/organization_invitations_unresolved_email_index/, fn ->
      Repo.insert!(
        struct!(OrganizationInvitation, %{
          attrs
          | id: Ecto.UUID.generate(),
            public_id: public_id()
        })
      )
    end

    assert_raise Ecto.ConstraintError, ~r/organization_invitations_creator_tenant_fkey/, fn ->
      Repo.insert!(
        struct!(OrganizationInvitation, %{
          raw_invitation_attrs(second, "cross-tenant@example.test")
          | created_by_membership_id: first.membership.id
        })
      )
    end

    assert_raise Ecto.ConstraintError,
                 ~r/organization_invitations_accepted_membership_tenant_fkey/,
                 fn ->
                   Repo.insert!(
                     struct!(
                       OrganizationInvitation,
                       Map.merge(
                         raw_invitation_attrs(first, "accepted-cross-tenant@example.test"),
                         %{
                           accepted_at: DateTime.utc_now(:microsecond),
                           accepted_membership_id: second.membership.id
                         }
                       )
                     )
                   )
                 end

    assert_raise Ecto.ConstraintError, ~r/organization_invitations_public_id_index/, fn ->
      Repo.insert!(
        struct!(OrganizationInvitation, %{
          raw_invitation_attrs(second, "duplicate-public-id@example.test")
          | public_id: attrs.public_id
        })
      )
    end

    assert_raise Ecto.ConstraintError, ~r/organization_invitations_terminal_state_check/, fn ->
      Repo.insert!(
        struct!(
          OrganizationInvitation,
          Map.merge(raw_invitation_attrs(first, "invalid-terminal@example.test"), %{
            accepted_at: DateTime.utc_now(:microsecond),
            accepted_membership_id: first.membership.id,
            revoked_at: DateTime.utc_now(:microsecond)
          })
        )
      )
    end
  end

  defp create_invitation(identity, email) do
    Accounts.create_organization_invitation(identity.auth_context, %{
      email: email,
      display_name: "Invitee",
      scopes: ["memory.read"],
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
    })
  end

  defp raw_invitation_attrs(identity, email) do
    now = DateTime.utc_now(:microsecond)

    %{
      id: Ecto.UUID.generate(),
      organization_id: identity.organization.id,
      created_by_membership_id: identity.membership.id,
      email: email,
      display_name: "Raw",
      role: "member",
      scopes: ["memory.read"],
      public_id: public_id(),
      secret_digest: :crypto.strong_rand_bytes(32),
      expires_at: DateTime.add(now, 3600, :second),
      inserted_at: now,
      updated_at: now
    }
  end

  defp public_id, do: :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
end
