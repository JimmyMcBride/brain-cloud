defmodule BrainCloud.Accounts.BrowserAuthenticationTest do
  use BrainCloud.DataCase, async: true

  alias BrainCloud.Accounts
  alias BrainCloud.Accounts.BrowserLoginChallenge
  alias BrainCloud.Accounts.BrowserSession
  alias BrainCloud.Accounts.UserAuthEvent

  test "closed enrollment accepts unknown and inactive users without issuing a challenge" do
    assert {:ok, :accepted} = Accounts.request_browser_login("nobody@example.test")
    assert Repo.aggregate(BrowserLoginChallenge, :count) == 0

    identity = identity_fixture()
    Repo.update!(change(identity.membership, deactivated_at: DateTime.utc_now(:microsecond)))

    assert {:ok, :accepted} = Accounts.request_browser_login(identity.user.email)
    assert Repo.aggregate(BrowserLoginChallenge, :count) == 0
  end

  test "eligible requests issue only a digest and supersede an older challenge" do
    identity = identity_fixture()
    now = ~U[2026-09-06 14:00:00.000000Z]

    assert {:ok, {:deliver, first, first_token, user}} =
             Accounts.request_browser_login(identity.user.email, now: now)

    assert user.id == identity.user.id
    refute first.token_digest == first_token
    refute inspect(first) =~ first_token
    assert byte_size(first.token_digest) == 32
    assert {:ok, sent} = Accounts.mark_browser_login_sent(first.id, now: now)
    assert sent.sent_at == now

    later = DateTime.add(now, 61, :second)

    assert {:ok, {:deliver, _second, second_token, _user}} =
             Accounts.request_browser_login(identity.user.email, now: later)

    refute second_token == first_token
    assert Repo.get!(BrowserLoginChallenge, first.id).revoked_at == later
    assert {:error, :login_unavailable} = Accounts.confirm_browser_login(first_token, now: later)
  end

  test "requests are throttled for sixty seconds and after five sent links per hour" do
    identity = identity_fixture()
    start = ~U[2026-09-06 14:00:00.000000Z]

    assert {:ok, {:deliver, first, _token, _user}} =
             Accounts.request_browser_login(identity.user.email, now: start)

    assert {:ok, _sent} = Accounts.mark_browser_login_sent(first.id, now: start)

    assert {:ok, :accepted} =
             Accounts.request_browser_login(identity.user.email,
               now: DateTime.add(start, 59, :second)
             )

    for offset <- [61, 122, 183, 244] do
      at = DateTime.add(start, offset, :second)

      assert {:ok, {:deliver, challenge, _token, _user}} =
               Accounts.request_browser_login(identity.user.email, now: at)

      assert {:ok, _sent} = Accounts.mark_browser_login_sent(challenge.id, now: at)
    end

    assert {:ok, :accepted} =
             Accounts.request_browser_login(identity.user.email,
               now: DateTime.add(start, 305, :second)
             )
  end

  test "delivery failure invalidates an unsent challenge" do
    identity = identity_fixture()

    assert {:ok, {:deliver, challenge, raw_token, _user}} =
             Accounts.request_browser_login(identity.user.email)

    assert :ok = Accounts.invalidate_browser_login(challenge.id)
    refute is_nil(Repo.get!(BrowserLoginChallenge, challenge.id).revoked_at)
    assert {:error, :login_unavailable} = Accounts.confirm_browser_login(raw_token)
  end

  test "confirmation is sent-only, single-use, verifies email, and creates a selected session" do
    identity = identity_fixture()
    now = ~U[2026-09-06 14:00:00.000000Z]

    assert {:ok, {:deliver, challenge, raw_token, _user}} =
             Accounts.request_browser_login(identity.user.email, now: now)

    assert {:error, :login_unavailable} = Accounts.confirm_browser_login(raw_token, now: now)
    assert {:ok, _sent} = Accounts.mark_browser_login_sent(challenge.id, now: now)

    assert {:ok, scope, session_token} = Accounts.confirm_browser_login(raw_token, now: now)
    assert scope.user.email_verified_at == now
    assert scope.selected_membership.id == identity.membership.id
    assert scope.organization.id == identity.organization.id
    assert scope.role == "owner"
    refute scope.session.token_digest == session_token
    assert scope.session.expires_at == DateTime.add(now, 14 * 24 * 60 * 60, :second)
    assert {:error, :login_unavailable} = Accounts.confirm_browser_login(raw_token, now: now)

    assert {:ok, loaded_scope, nil} =
             Accounts.authenticate_browser_session(session_token, now: now)

    assert loaded_scope.user.id == identity.user.id

    assert Repo.all(
             from event in UserAuthEvent, order_by: event.inserted_at, select: event.action
           ) ==
             ["email.verify", "session.create"]
  end

  test "expired and malformed confirmations return the same unavailable result" do
    identity = identity_fixture()
    now = ~U[2026-09-06 14:00:00.000000Z]

    assert {:ok, {:deliver, challenge, raw_token, _user}} =
             Accounts.request_browser_login(identity.user.email, now: now)

    assert {:ok, _sent} = Accounts.mark_browser_login_sent(challenge.id, now: now)

    assert {:error, :login_unavailable} =
             Accounts.confirm_browser_login(raw_token, now: DateTime.add(now, 901, :second))

    assert {:error, :login_unavailable} = Accounts.confirm_browser_login("not-a-token", now: now)

    replacement = if String.last(raw_token) == "x", do: "y", else: "x"
    wrong_secret = String.replace_suffix(raw_token, String.last(raw_token), replacement)
    assert {:error, :login_unavailable} = Accounts.confirm_browser_login(wrong_secret, now: now)
  end

  test "multiple memberships require authoritative selection and refresh role changes" do
    primary = identity_fixture()
    other = identity_fixture()

    assert {:ok, second_membership} =
             Accounts.create_organization_membership(other.auth_context, %{
               email: primary.user.email,
               display_name: primary.user.display_name,
               role: "member"
             })

    {scope, session_token} = sign_in(primary.user.email)
    assert is_nil(scope.selected_membership)
    assert length(scope.memberships) == 2

    assert {:ok, selected_scope} =
             Accounts.select_browser_membership(session_token, second_membership.id)

    assert selected_scope.organization.id == other.organization.id
    assert selected_scope.role == "member"

    assert {:ok, _updated_membership} =
             Accounts.update_organization_membership_role(
               other.auth_context,
               second_membership.id,
               "owner"
             )

    assert {:ok, refreshed_scope, nil} = Accounts.authenticate_browser_session(session_token)
    assert refreshed_scope.role == "owner"

    auth_events =
      Repo.all(
        from event in UserAuthEvent,
          order_by: event.inserted_at,
          select: {event.action, event.metadata}
      )

    assert {"organization.select",
            %{
              "organization_id" => other.organization.id,
              "membership_id" => second_membership.id
            }} in auth_events

    serialized_events = inspect(auth_events)
    refute serialized_events =~ primary.user.email
    refute serialized_events =~ session_token
    refute serialized_events =~ Base.encode16(refreshed_scope.session.token_digest, case: :lower)
  end

  test "an inactive selection returns the chooser while no active membership revokes the session" do
    primary = identity_fixture()
    other = identity_fixture()

    assert {:ok, second_membership} =
             Accounts.create_organization_membership(other.auth_context, %{
               email: primary.user.email,
               display_name: primary.user.display_name,
               role: "member"
             })

    {_scope, session_token} = sign_in(primary.user.email)
    assert {:ok, _scope} = Accounts.select_browser_membership(session_token, second_membership.id)

    assert {:ok, _membership} =
             Accounts.deactivate_organization_membership(other.auth_context, second_membership.id)

    assert {:ok, chooser_scope, nil} = Accounts.authenticate_browser_session(session_token)
    assert is_nil(chooser_scope.selected_membership)
    assert Enum.map(chooser_scope.memberships, & &1.id) == [primary.membership.id]

    Repo.update!(change(primary.membership, deactivated_at: DateTime.utc_now(:microsecond)))

    assert {:error, :unauthorized} = Accounts.authenticate_browser_session(session_token)
    refute is_nil(Repo.get_by!(BrowserSession, user_id: primary.user.id).revoked_at)
  end

  test "sessions reissue once after seven days and logout is idempotent" do
    identity = identity_fixture()
    signed_in_at = ~U[2026-09-01 14:00:00.000000Z]
    {_scope, session_token} = sign_in(identity.user.email, signed_in_at)
    old_session = Repo.get_by!(BrowserSession, user_id: identity.user.id)
    reissue_at = DateTime.add(signed_in_at, 8 * 24 * 60 * 60, :second)

    Repo.update_all(from(session in BrowserSession, where: session.id == ^old_session.id),
      set: [inserted_at: signed_in_at]
    )

    assert {:ok, scope, replacement_token} =
             Accounts.authenticate_browser_session(session_token, now: reissue_at)

    assert is_binary(replacement_token)
    refute replacement_token == session_token
    refute scope.session.id == old_session.id
    assert scope.session.expires_at == old_session.expires_at
    refute is_nil(Repo.get!(BrowserSession, old_session.id).revoked_at)
    assert {:error, :unauthorized} = Accounts.authenticate_browser_session(session_token)

    assert :ok = Accounts.logout_browser_session(replacement_token)
    assert :ok = Accounts.logout_browser_session(replacement_token)
    assert {:error, :unauthorized} = Accounts.authenticate_browser_session(replacement_token)

    assert Repo.aggregate(
             from(event in UserAuthEvent, where: event.action == "session.logout"),
             :count
           ) == 1

    assert Repo.aggregate(
             from(event in UserAuthEvent, where: event.action == "session.reissue"),
             :count
           ) == 1
  end

  test "recent authentication lasts twenty minutes" do
    identity = identity_fixture()
    now = ~U[2026-09-06 14:00:00.000000Z]
    {scope, _session_token} = sign_in(identity.user.email, now)

    assert Accounts.recently_authenticated?(scope, now: DateTime.add(now, 1199, :second))
    refute Accounts.recently_authenticated?(scope, now: DateTime.add(now, 1200, :second))
  end

  test "logging out an expired session is an idempotent signed-out no-op" do
    identity = identity_fixture()
    signed_in_at = ~U[2026-08-01 14:00:00.000000Z]
    {_scope, session_token} = sign_in(identity.user.email, signed_in_at)

    assert :ok =
             Accounts.logout_browser_session(session_token,
               now: DateTime.add(signed_in_at, 14 * 24 * 60 * 60, :second)
             )

    refute Repo.exists?(from event in UserAuthEvent, where: event.action == "session.logout")
  end

  defp sign_in(email, now \\ DateTime.utc_now(:microsecond)) do
    assert {:ok, {:deliver, challenge, raw_token, _user}} =
             Accounts.request_browser_login(email, now: now)

    assert {:ok, _sent} = Accounts.mark_browser_login_sent(challenge.id, now: now)
    assert {:ok, scope, session_token} = Accounts.confirm_browser_login(raw_token, now: now)
    {scope, session_token}
  end
end
