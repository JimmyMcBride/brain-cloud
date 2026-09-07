defmodule BrainCloud.OrganizationInvitationRaceTest do
  use ExUnit.Case, async: false

  import BrainCloud.DataCase, only: [identity_fixture: 0]
  import Ecto.Query

  alias BrainCloud.Accounts
  alias BrainCloud.Accounts.ApiToken
  alias BrainCloud.Accounts.AuditEvent
  alias BrainCloud.Accounts.OrganizationInvitation
  alias BrainCloud.Accounts.OrganizationMembership
  alias BrainCloud.Repo
  alias Ecto.Adapters.SQL.Sandbox

  test "concurrent send reservations yield one generation and one cooldown" do
    setup = unboxed(&invitation_setup/0)
    on_exit(fn -> unboxed(fn -> cleanup(setup) end) end)
    token = unboxed(fn -> owner_session(setup) end)

    results =
      race(
        fn -> BrainCloud.Accounts.InvitationDelivery.reserve(token, setup.invitation.id) end,
        fn -> BrainCloud.Accounts.InvitationDelivery.reserve(token, setup.invitation.id) end
      )

    assert Enum.count(results, &match?({:ok, _}, &1)) == 1
    assert Enum.count(results, &match?({:error, {:throttled, _}}, &1)) == 1
  end

  test "send finalization racing revocation cannot revive a token" do
    setup = unboxed(&invitation_setup/0)
    on_exit(fn -> unboxed(fn -> cleanup(setup) end) end)

    {token, reservation} =
      unboxed(fn ->
        token = owner_session(setup)

        {:ok, reservation} =
          BrainCloud.Accounts.InvitationDelivery.reserve(token, setup.invitation.id)

        {token, reservation}
      end)

    race(
      fn -> BrainCloud.Accounts.InvitationDelivery.finish(reservation.attempt.id, :sent) end,
      fn -> BrainCloud.Accounts.InvitationDelivery.revoke(token, setup.invitation.id) end
    )

    assert unboxed(fn -> Accounts.accept_browser_invitation(reservation.token) end) ==
             {:error, :invitation_not_found}
  end

  defp owner_session(setup) do
    user = Repo.get!(BrainCloud.Accounts.User, setup.owner_user_id)
    {:ok, {:deliver, challenge, raw, _}} = Accounts.request_browser_login(user.email)
    {:ok, _} = Accounts.mark_browser_login_sent(challenge.id)
    {:ok, _, token} = Accounts.confirm_browser_login(raw)
    token
  end

  test "concurrent browser admission creates one membership and no credential" do
    setup = unboxed(&invitation_setup/0)
    on_exit(fn -> unboxed(fn -> cleanup(setup) end) end)

    results =
      race(fn -> Accounts.accept_browser_invitation(setup.raw_token) end, fn ->
        Accounts.accept_browser_invitation(setup.raw_token)
      end)

    assert Enum.count(results, &match?({:ok, _}, &1)) == 1
    assert Enum.count(results, &(&1 == {:error, :invitation_not_found})) == 1
    assert_counts(setup, memberships: 1, tokens: 0, acceptance_audits: 1)
  end

  test "browser and API admission race commits one transport's effects" do
    setup = unboxed(&invitation_setup/0)
    on_exit(fn -> unboxed(fn -> cleanup(setup) end) end)

    [browser, api] =
      race(fn -> Accounts.accept_browser_invitation(setup.raw_token) end, fn ->
        Accounts.accept_organization_invitation(setup.raw_token)
      end)

    assert Enum.count([browser, api], &match?({:ok, _}, &1)) == 1
    assert Enum.count([browser, api], &(&1 == {:error, :invitation_not_found})) == 1
    tokens = if match?({:ok, _}, api), do: 1, else: 0
    assert_counts(setup, memberships: 1, tokens: tokens, acceptance_audits: 1)
  end

  test "concurrent acceptance creates exactly one membership, token, and audit" do
    setup = unboxed(&invitation_setup/0)
    on_exit(fn -> unboxed(fn -> cleanup(setup) end) end)

    results =
      race(fn -> Accounts.accept_organization_invitation(setup.raw_token) end, fn ->
        Accounts.accept_organization_invitation(setup.raw_token)
      end)

    assert Enum.count(results, &match?({:ok, _result}, &1)) == 1
    assert Enum.count(results, &(&1 == {:error, :invitation_not_found})) == 1

    assert_counts(setup, memberships: 1, tokens: 1, acceptance_audits: 1)
    assert unboxed(fn -> Repo.get!(OrganizationInvitation, setup.invitation.id).accepted_at end)
  end

  test "concurrent duplicate creation returns one invitation and one exact conflict" do
    setup = unboxed(&owner_setup/0)
    on_exit(fn -> unboxed(fn -> cleanup(setup) end) end)
    attrs = invitation_attrs(setup.email)

    results =
      race(
        fn -> Accounts.create_organization_invitation(setup.auth, attrs) end,
        fn -> Accounts.create_organization_invitation(setup.auth, attrs) end
      )

    assert Enum.count(results, &match?({:ok, %OrganizationInvitation{}, _raw}, &1)) == 1
    assert Enum.count(results, &(&1 == {:error, :invitation_exists})) == 1

    assert unboxed(fn ->
             Repo.aggregate(
               from(invitation in OrganizationInvitation,
                 where:
                   invitation.organization_id == ^setup.organization_id and
                     invitation.email == ^setup.email
               ),
               :count,
               :id
             )
           end) == 1

    assert unboxed(fn -> audit_count(setup.organization_id, "invitation.create") end) == 1
  end

  test "acceptance and revoke serialize to one terminal state" do
    setup = unboxed(&invitation_setup/0)
    on_exit(fn -> unboxed(fn -> cleanup(setup) end) end)

    [accept_result, revoke_result] =
      race(fn -> Accounts.accept_organization_invitation(setup.raw_token) end, fn ->
        Accounts.revoke_organization_invitation(setup.auth, setup.invitation.id)
      end)

    assert revoke_result == {:ok, :ok}
    invitation = unboxed(fn -> Repo.get!(OrganizationInvitation, setup.invitation.id) end)

    case accept_result do
      {:ok, _result} ->
        assert invitation.accepted_at
        assert invitation.revoked_at == nil
        assert_counts(setup, memberships: 1, tokens: 1, acceptance_audits: 1)
        assert unboxed(fn -> audit_count(setup.organization_id, "invitation.revoke") end) == 0

      {:error, :invitation_not_found} ->
        assert invitation.revoked_at
        assert invitation.accepted_at == nil
        assert_counts(setup, memberships: 0, tokens: 0, acceptance_audits: 0)
        assert unboxed(fn -> audit_count(setup.organization_id, "invitation.revoke") end) == 1
    end
  end

  test "acceptance and direct membership creation commit one membership without partial effects" do
    setup = unboxed(&invitation_setup/0)
    on_exit(fn -> unboxed(fn -> cleanup(setup) end) end)

    [accept_result, direct_result] =
      race(fn -> Accounts.accept_organization_invitation(setup.raw_token) end, fn ->
        Accounts.create_organization_membership(setup.auth, %{
          email: setup.email,
          display_name: "Direct",
          role: "member"
        })
      end)

    assert Enum.count([accept_result, direct_result], &match?({:ok, _result}, &1)) == 1
    assert Enum.count([accept_result, direct_result], &(&1 == {:error, :membership_exists})) == 1

    case accept_result do
      {:ok, _result} ->
        assert_counts(setup, memberships: 1, tokens: 1, acceptance_audits: 1)

      {:error, :membership_exists} ->
        assert_counts(setup, memberships: 1, tokens: 0, acceptance_audits: 0)
        invitation = unboxed(fn -> Repo.get!(OrganizationInvitation, setup.invitation.id) end)
        assert invitation.accepted_at == nil
    end
  end

  defp invitation_setup do
    setup = owner_setup()

    {:ok, invitation, raw_token} =
      Accounts.create_organization_invitation(setup.auth, invitation_attrs(setup.email))

    Map.merge(setup, %{invitation: invitation, raw_token: raw_token})
  end

  defp owner_setup do
    identity = identity_fixture()

    %{
      auth: identity.auth_context,
      organization_id: identity.organization.id,
      owner_user_id: identity.user.id,
      owner_membership_id: identity.membership.id,
      email: "race-#{Ecto.UUID.generate()}@example.test"
    }
  end

  defp invitation_attrs(email) do
    %{
      email: email,
      display_name: "Race Invitee",
      scopes: ["memory.read"],
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
    }
  end

  defp race(left_fun, right_fun) do
    parent = self()

    tasks =
      for {side, fun} <- [left: left_fun, right: right_fun] do
        Task.async(fn ->
          unboxed(fn ->
            backend_pid = backend_pid()
            send(parent, {:race_ready, side, self(), backend_pid})
            receive do: (:race_go -> :ok)
            {backend_pid, fun.()}
          end)
        end)
      end

    assert_receive {:race_ready, :left, left_pid, left_backend}, 5_000
    assert_receive {:race_ready, :right, right_pid, right_backend}, 5_000
    assert left_backend != right_backend
    send(left_pid, :race_go)
    send(right_pid, :race_go)

    Enum.map(tasks, fn task ->
      {_backend_pid, result} = Task.await(task, 5_000)
      result
    end)
  end

  defp assert_counts(setup, expected) do
    counts =
      unboxed(fn ->
        membership_ids =
          Repo.all(
            from membership in OrganizationMembership,
              join: user in assoc(membership, :user),
              where:
                membership.organization_id == ^setup.organization_id and
                  user.email == ^setup.email,
              select: membership.id
          )

        %{
          memberships: length(membership_ids),
          tokens:
            Repo.aggregate(
              from(token in ApiToken, where: token.membership_id in ^membership_ids),
              :count,
              :id
            ),
          acceptance_audits: audit_count(setup.organization_id, "invitation.accept")
        }
      end)

    assert counts == Map.new(expected)
  end

  defp audit_count(organization_id, action) do
    Repo.aggregate(
      from(event in AuditEvent,
        where: event.organization_id == ^organization_id and event.action == ^action
      ),
      :count,
      :id
    )
  end

  defp backend_pid do
    %{rows: [[pid]]} = Repo.query!("SELECT pg_backend_pid()")
    pid
  end

  defp cleanup(setup) do
    organization_id = Ecto.UUID.dump!(setup.organization_id)
    owner_user_id = Ecto.UUID.dump!(setup.owner_user_id)

    Repo.query!("DELETE FROM audit_events WHERE organization_id = $1", [organization_id])

    Repo.query!(
      "UPDATE organization_invitations SET delivery_generation = NULL, delivery_state = 'manual' WHERE organization_id = $1",
      [organization_id]
    )

    Repo.query!("DELETE FROM invitation_delivery_attempts WHERE organization_id = $1", [
      organization_id
    ])

    Repo.query!("DELETE FROM user_auth_events WHERE user_id = $1", [owner_user_id])
    Repo.query!("DELETE FROM browser_sessions WHERE user_id = $1", [owner_user_id])
    Repo.query!("DELETE FROM browser_login_challenges WHERE user_id = $1", [owner_user_id])

    Repo.query!("DELETE FROM organization_invitations WHERE organization_id = $1", [
      organization_id
    ])

    Repo.query!(
      "DELETE FROM api_tokens WHERE membership_id IN (SELECT id FROM organization_memberships WHERE organization_id = $1)",
      [organization_id]
    )

    Repo.query!("DELETE FROM organization_memberships WHERE organization_id = $1", [
      organization_id
    ])

    Repo.query!("DELETE FROM organizations WHERE id = $1", [organization_id])
    Repo.query!("DELETE FROM users WHERE id = $1 OR email = $2", [owner_user_id, setup.email])
  end

  defp unboxed(fun), do: Sandbox.unboxed_run(Repo, fun)
end
