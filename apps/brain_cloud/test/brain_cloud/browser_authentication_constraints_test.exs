defmodule BrainCloud.BrowserAuthenticationConstraintsTest do
  use BrainCloud.DataCase, async: true

  alias BrainCloud.Accounts.BrowserLoginChallenge
  alias BrainCloud.Accounts.BrowserSession

  test "challenge and session token digests must be SHA-256 length", %{test: test} do
    identity = identity_fixture()
    now = DateTime.utc_now(:microsecond)

    assert_constraint("browser_login_challenges_digest_length_check", fn ->
      Repo.insert!(%BrowserLoginChallenge{
        user_id: identity.user.id,
        public_id: public_id(test, "challenge"),
        token_digest: <<1>>
      })
    end)

    assert_constraint("browser_sessions_digest_length_check", fn ->
      Repo.insert!(%BrowserSession{
        user_id: identity.user.id,
        public_id: public_id(test, "session"),
        token_digest: <<1>>,
        authenticated_at: now,
        expires_at: DateTime.add(now, 3600, :second)
      })
    end)
  end

  test "selected membership must belong to the session user", %{test: test} do
    identity = identity_fixture()
    stranger = identity_fixture()
    now = DateTime.utc_now(:microsecond)

    assert_constraint("browser_sessions_selected_membership_user_fkey", fn ->
      Repo.insert!(%BrowserSession{
        user_id: identity.user.id,
        selected_membership_id: stranger.membership.id,
        public_id: public_id(test, "ownership"),
        token_digest: :crypto.strong_rand_bytes(32),
        authenticated_at: now,
        expires_at: DateTime.add(now, 3600, :second)
      })
    end)
  end

  test "only one unresolved challenge can exist per user", %{test: test} do
    identity = identity_fixture()

    attrs = %{user_id: identity.user.id}

    Repo.insert!(
      struct!(
        BrowserLoginChallenge,
        Map.merge(attrs, %{
          public_id: public_id(test, "one"),
          token_digest: :crypto.strong_rand_bytes(32)
        })
      )
    )

    assert_constraint("browser_login_challenges_active_user_index", fn ->
      Repo.insert!(
        struct!(
          BrowserLoginChallenge,
          Map.merge(attrs, %{
            public_id: public_id(test, "two"),
            token_digest: :crypto.strong_rand_bytes(32)
          })
        )
      )
    end)
  end

  test "challenge and session token digests are unique", %{test: test} do
    identity = identity_fixture()
    other = identity_fixture()
    now = DateTime.utc_now(:microsecond)
    challenge_digest = :crypto.strong_rand_bytes(32)
    session_digest = :crypto.strong_rand_bytes(32)

    Repo.insert!(%BrowserLoginChallenge{
      user_id: identity.user.id,
      public_id: public_id(test, "challenge-one"),
      token_digest: challenge_digest
    })

    assert_constraint("browser_login_challenges_token_digest_index", fn ->
      Repo.insert!(%BrowserLoginChallenge{
        user_id: other.user.id,
        public_id: public_id(test, "challenge-two"),
        token_digest: challenge_digest
      })
    end)

    Repo.insert!(%BrowserSession{
      user_id: identity.user.id,
      public_id: public_id(test, "session-one"),
      token_digest: session_digest,
      authenticated_at: now,
      expires_at: DateTime.add(now, 3600, :second)
    })

    assert_constraint("browser_sessions_token_digest_index", fn ->
      Repo.insert!(%BrowserSession{
        user_id: other.user.id,
        public_id: public_id(test, "session-two"),
        token_digest: session_digest,
        authenticated_at: now,
        expires_at: DateTime.add(now, 3600, :second)
      })
    end)
  end

  defp assert_constraint(name, fun) do
    assert_raise Ecto.ConstraintError, ~r/#{name}/, fun
  end

  defp public_id(test, suffix) do
    :crypto.hash(:sha256, "#{test}-#{suffix}")
    |> Base.encode16(case: :lower)
    |> binary_part(0, 32)
  end
end
