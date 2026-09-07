defmodule BrainCloud.Accounts.InvitationDeliveryTest do
  use BrainCloud.DataCase, async: false
  alias BrainCloud.Accounts

  alias BrainCloud.Accounts.{
    InvitationDelivery,
    InvitationDeliveryAttempt,
    OrganizationInvitation,
    AuditEvent
  }

  test "create, send, supersede and fail preserve expiry and keep only sent links usable" do
    owner = identity_fixture()
    session = session(owner)

    {:ok, first} =
      InvitationDelivery.create(session, %{
        "email" => "deliver@example.test",
        "display_name" => "Recipient"
      })

    assert first.invitation.delivery_state == "sending"
    assert {:error, :invitation_not_found} = Accounts.preview_browser_invitation(first.token, nil)
    assert {:error, :invitation_not_found} = Accounts.accept_organization_invitation(first.token)
    assert {:ok, :sent} = InvitationDelivery.finish(first.attempt.id, :sent)
    assert {:ok, _} = Accounts.preview_browser_invitation(first.token, nil)
    assert {:error, {:throttled, _}} = InvitationDelivery.reserve(session, first.invitation.id)
    later = DateTime.add(first.attempt.inserted_at, 61, :second)
    assert {:ok, second} = InvitationDelivery.reserve(session, first.invitation.id, now: later)
    assert second.token != first.token
    assert second.invitation.expires_at == first.invitation.expires_at
    assert {:error, :invitation_not_found} = Accounts.accept_browser_invitation(first.token)
    assert {:ok, :stale} = InvitationDelivery.finish(first.attempt.id, :sent)
    assert {:ok, :failed} = InvitationDelivery.finish(second.attempt.id, :failed)
    assert {:error, :invitation_not_found} = Accounts.accept_browser_invitation(second.token)
    assert Repo.get!(OrganizationInvitation, first.invitation.id).delivery_state == "failed"

    for event <- Repo.all(AuditEvent) do
      refute inspect(event.metadata) =~ first.token
      refute inspect(event.metadata) =~ "deliver@example.test"
    end
  end

  test "revocation defeats stale completion and owner demotion blocks further requests" do
    owner = identity_fixture()
    session = session(owner)

    {:ok, reservation} =
      InvitationDelivery.create(session, %{
        "email" => "stale@example.test",
        "display_name" => "Recipient"
      })

    assert {:ok, :ok} = InvitationDelivery.revoke(session, reservation.invitation.id)
    assert {:ok, :stale} = InvitationDelivery.finish(reservation.attempt.id, :sent)
    assert {:error, :invitation_not_found} = Accounts.accept_browser_invitation(reservation.token)
    owner.membership |> Ecto.Changeset.change(role: "member") |> Repo.update!()
    assert {:error, :invitation_not_found} = InvitationDelivery.list(session)

    assert {:error, :invitation_not_found} =
             InvitationDelivery.reserve(session, reservation.invitation.id)
  end

  test "organization quota counts failed attempts and rolls back quota-blocked creation" do
    owner = identity_fixture()
    session = session(owner)

    for number <- 1..20 do
      {:ok, reservation} =
        InvitationDelivery.create(session, %{
          "email" => "quota-#{number}@example.test",
          "display_name" => "Recipient"
        })

      assert {:ok, :failed} = InvitationDelivery.finish(reservation.attempt.id, :failed)
    end

    assert {:error, {:throttled, _}} =
             InvitationDelivery.create(session, %{
               "email" => "blocked@example.test",
               "display_name" => "Recipient"
             })

    refute Repo.get_by(OrganizationInvitation, email: "blocked@example.test")
    assert Repo.aggregate(InvitationDeliveryAttempt, :count) == 20
  end

  test "per invitation quota counts failures and wrong tenant cannot read or send" do
    owner = identity_fixture()
    session = session(owner)

    {:ok, first} =
      InvitationDelivery.create(session, %{
        "email" => "retries@example.test",
        "display_name" => "Recipient"
      })

    for number <- 1..4 do
      {:ok, attempt} =
        InvitationDelivery.reserve(session, first.invitation.id,
          now: DateTime.add(first.attempt.inserted_at, number * 61, :second)
        )

      assert {:ok, :failed} = InvitationDelivery.finish(attempt.attempt.id, :failed)
    end

    assert {:error, {:throttled, _}} =
             InvitationDelivery.reserve(session, first.invitation.id,
               now: DateTime.add(first.attempt.inserted_at, 305, :second)
             )

    other_session = session(identity_fixture())
    assert {:ok, []} = InvitationDelivery.list(other_session)

    assert {:error, :invitation_not_found} =
             InvitationDelivery.reserve(other_session, first.invitation.id)
  end

  test "matching browser selects membership; mismatched browser cannot admit" do
    owner = identity_fixture()
    invitee = identity_fixture(%{email: "matching@example.test"})

    {:ok, invitation, raw} =
      Accounts.create_organization_invitation(owner.auth_context, %{
        email: invitee.user.email,
        display_name: "New",
        scopes: ["memory.read"],
        expires_at: DateTime.add(DateTime.utc_now(), 3600)
      })

    assert {:error, :identity_mismatch} = Accounts.accept_browser_invitation(raw, session(owner))
    assert Repo.get!(OrganizationInvitation, invitation.id).accepted_at == nil
    matching = session(invitee)
    assert {:ok, result} = Accounts.accept_browser_invitation(raw, matching)
    assert {:ok, scope, nil} = Accounts.authenticate_browser_session(matching, rotate: false)
    assert scope.selected_membership.id == result.membership.id
  end

  defp session(identity) do
    {:ok, {:deliver, challenge, raw, _}} = Accounts.request_browser_login(identity.user.email)
    {:ok, _} = Accounts.mark_browser_login_sent(challenge.id)
    {:ok, _, session} = Accounts.confirm_browser_login(raw)
    session
  end
end
