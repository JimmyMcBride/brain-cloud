defmodule BrainCloud.Accounts.BrowserAuthentication do
  @moduledoc """
  Closed-enrollment, passwordless browser authentication for existing human users.

  Raw login and session tokens are returned only to the web boundary. PostgreSQL
  stores SHA-256 digests and a non-secret public lookup identifier.
  """

  import Ecto.Query

  alias BrainCloud.Accounts.BrowserLoginChallenge
  alias BrainCloud.Accounts.BrowserScope
  alias BrainCloud.Accounts.BrowserSession
  alias BrainCloud.Accounts.OrganizationMembership
  alias BrainCloud.Accounts.User
  alias BrainCloud.Accounts.UserAuthEvent
  alias BrainCloud.Repo
  alias Ecto.Changeset

  @login_pattern ~r/\Abcl1_([0-9a-f]{32})_([A-Za-z0-9_-]{43})\z/
  @session_pattern ~r/\Abcs1_([0-9a-f]{32})_([A-Za-z0-9_-]{43})\z/
  @challenge_lifetime_seconds 15 * 60
  @session_lifetime_seconds 14 * 24 * 60 * 60
  @session_reissue_seconds 7 * 24 * 60 * 60
  @recent_auth_seconds 20 * 60
  @request_cooldown_seconds 60
  @hourly_request_limit 5

  def request_login(email, opts \\ []) do
    now = now(opts)
    normalized_email = normalize_email(email)

    result =
      Repo.transaction(fn ->
        case eligible_user_for_update(normalized_email) do
          nil ->
            dummy_token_work()
            :accepted

          %User{} = user ->
            if throttled?(user.id, now) do
              dummy_token_work()
              :accepted
            else
              revoke_open_challenges(user.id, now)
              {raw_token, attrs} = token_attrs("bcl1")

              case %BrowserLoginChallenge{}
                   |> BrowserLoginChallenge.changeset(Map.put(attrs, :user_id, user.id))
                   |> Repo.insert() do
                {:ok, challenge} -> {:deliver, challenge, raw_token, user}
                {:error, reason} -> Repo.rollback(reason)
              end
            end
        end
      end)

    case result do
      {:ok, value} -> {:ok, value}
      {:error, reason} -> {:error, reason}
    end
  end

  def mark_login_sent(challenge_id, opts \\ []) do
    now = now(opts)

    Repo.transaction(fn ->
      case login_challenge_for_update(challenge_id) do
        %BrowserLoginChallenge{consumed_at: nil, revoked_at: nil} = challenge ->
          challenge
          |> Changeset.change(sent_at: challenge.sent_at || now)
          |> Repo.update!()

        _unavailable ->
          Repo.rollback(:login_unavailable)
      end
    end)
    |> unwrap_transaction()
  end

  def invalidate_login(challenge_id, opts \\ []) do
    now = now(opts)

    Repo.transaction(fn ->
      case login_challenge_for_update(challenge_id) do
        %BrowserLoginChallenge{consumed_at: nil, revoked_at: nil} = challenge ->
          challenge
          |> Changeset.change(revoked_at: now)
          |> Repo.update!()

        _unavailable ->
          :ok
      end
    end)
    |> case do
      {:ok, _result} -> :ok
      {:error, _reason} -> :ok
    end
  end

  def confirm_login(raw_token, opts \\ [])

  def confirm_login(raw_token, opts) when is_binary(raw_token) do
    now = now(opts)

    with [_, public_id, _secret] <- Regex.run(@login_pattern, raw_token) do
      Repo.transaction(fn ->
        case challenge_by_public_id_for_update(public_id) do
          %BrowserLoginChallenge{} = challenge ->
            if valid_challenge?(challenge, raw_token, now) do
              consume_challenge(challenge, now)
            else
              Repo.rollback(:login_unavailable)
            end

          nil ->
            dummy_token_work()
            Repo.rollback(:login_unavailable)
        end
      end)
      |> case do
        {:ok, {scope, session_token}} -> {:ok, scope, session_token}
        {:error, _reason} -> {:error, :login_unavailable}
      end
    else
      _invalid ->
        dummy_token_work()
        {:error, :login_unavailable}
    end
  end

  def confirm_login(_raw_token, _opts) do
    dummy_token_work()
    {:error, :login_unavailable}
  end

  def authenticate_session(raw_token, opts \\ [])

  def authenticate_session(raw_token, opts) when is_binary(raw_token) do
    now = now(opts)
    rotate? = Keyword.get(opts, :rotate, true)

    with [_, public_id, _secret] <- Regex.run(@session_pattern, raw_token) do
      Repo.transaction(fn ->
        case session_by_public_id_for_update(public_id) do
          %BrowserSession{} = session ->
            authenticate_locked_session(session, raw_token, now, rotate?)

          nil ->
            dummy_token_work()
            Repo.rollback(:unauthorized)
        end
      end)
      |> case do
        {:ok, :revoked} -> {:error, :unauthorized}
        {:ok, result} -> {:ok, result.scope, result.replacement_token}
        {:error, _reason} -> {:error, :unauthorized}
      end
    else
      _invalid ->
        dummy_token_work()
        {:error, :unauthorized}
    end
  end

  def authenticate_session(_raw_token, _opts) do
    dummy_token_work()
    {:error, :unauthorized}
  end

  def select_membership(raw_token, membership_id, opts \\ [])

  def select_membership(raw_token, membership_id, opts)
      when is_binary(raw_token) and is_binary(membership_id) do
    now = now(opts)

    with [_, public_id, _secret] <- Regex.run(@session_pattern, raw_token),
         {:ok, membership_id} <- Ecto.UUID.cast(membership_id) do
      Repo.transaction(fn ->
        with %BrowserSession{} = session <- session_by_public_id_for_update(public_id),
             true <- valid_session?(session, raw_token, now),
             %OrganizationMembership{} = membership <-
               active_membership(session.user_id, membership_id) do
          {:ok, updated_session} =
            session
            |> Changeset.change(selected_membership_id: membership.id)
            |> Repo.update()

          insert_event!(updated_session, "organization.select", %{
            "organization_id" => membership.organization_id,
            "membership_id" => membership.id
          })

          build_scope(updated_session, active_memberships(updated_session.user_id))
        else
          _invalid -> Repo.rollback(:unauthorized)
        end
      end)
      |> case do
        {:ok, scope} -> {:ok, scope}
        {:error, _reason} -> {:error, :unauthorized}
      end
    else
      _invalid -> {:error, :unauthorized}
    end
  end

  def select_membership(_raw_token, _membership_id, _opts), do: {:error, :unauthorized}

  def logout(raw_token, opts \\ [])

  def logout(raw_token, opts) when is_binary(raw_token) do
    now = now(opts)

    with [_, public_id, _secret] <- Regex.run(@session_pattern, raw_token) do
      Repo.transaction(fn ->
        case session_by_public_id_for_update(public_id) do
          %BrowserSession{revoked_at: nil} = session ->
            if valid_session?(session, raw_token, now) do
              {:ok, revoked_session} =
                session
                |> Changeset.change(revoked_at: now)
                |> Repo.update()

              insert_event!(revoked_session, "session.logout")
            end

          _unavailable ->
            :ok
        end
      end)
    end

    :ok
  end

  def logout(_raw_token, _opts), do: :ok

  def recently_authenticated?(%BrowserScope{session: session}, opts \\ []) do
    elapsed = DateTime.diff(now(opts), session.authenticated_at, :second)
    elapsed >= 0 and elapsed < @recent_auth_seconds
  end

  defp consume_challenge(challenge, now) do
    memberships = active_memberships(challenge.user_id)

    if memberships == [] do
      Repo.rollback(:login_unavailable)
    end

    selected_membership_id =
      case memberships do
        [membership] -> membership.id
        _multiple -> nil
      end

    user = Repo.get!(User, challenge.user_id)
    first_verification? = is_nil(user.email_verified_at)

    {:ok, user} =
      if first_verification? do
        user |> Changeset.change(email_verified_at: now) |> Repo.update()
      else
        {:ok, user}
      end

    {:ok, _challenge} =
      challenge
      |> Changeset.change(consumed_at: now)
      |> Repo.update()

    {session_token, session_attrs} = token_attrs("bcs1")

    {:ok, session} =
      %BrowserSession{}
      |> BrowserSession.changeset(
        Map.merge(session_attrs, %{
          user_id: user.id,
          selected_membership_id: selected_membership_id,
          authenticated_at: now,
          expires_at: DateTime.add(now, @session_lifetime_seconds, :second)
        })
      )
      |> Repo.insert()

    if first_verification?, do: insert_event!(session, "email.verify")
    insert_event!(session, "session.create")

    {build_scope(session, memberships, user), session_token}
  end

  defp authenticate_locked_session(session, raw_token, now, rotate?) do
    if valid_session?(session, raw_token, now) do
      memberships = active_memberships(session.user_id)

      cond do
        memberships == [] ->
          {:ok, revoked_session} =
            session |> Changeset.change(revoked_at: now) |> Repo.update()

          insert_event!(revoked_session, "session.logout", %{"reason" => "no_active_memberships"})
          :revoked

        selection_inactive?(session, memberships) ->
          {:ok, cleared_session} =
            session |> Changeset.change(selected_membership_id: nil) |> Repo.update()

          %{scope: build_scope(cleared_session, memberships), replacement_token: nil}

        rotate? and reissue_due?(session, now) ->
          reissue_session(session, memberships, now)

        true ->
          %{scope: build_scope(session, memberships), replacement_token: nil}
      end
    else
      Repo.rollback(:unauthorized)
    end
  end

  defp reissue_session(session, memberships, now) do
    {replacement_token, attrs} = token_attrs("bcs1")

    {:ok, replacement} =
      %BrowserSession{}
      |> BrowserSession.changeset(
        Map.merge(attrs, %{
          user_id: session.user_id,
          selected_membership_id: session.selected_membership_id,
          authenticated_at: session.authenticated_at,
          expires_at: session.expires_at
        })
      )
      |> Repo.insert()

    {:ok, _old_session} =
      session |> Changeset.change(revoked_at: now) |> Repo.update()

    insert_event!(replacement, "session.reissue", %{"previous_session_id" => session.id})

    %{scope: build_scope(replacement, memberships), replacement_token: replacement_token}
  end

  defp build_scope(session, memberships, user \\ nil) do
    user = user || Repo.get!(User, session.user_id)
    selected = Enum.find(memberships, &(&1.id == session.selected_membership_id))

    %BrowserScope{
      user: user,
      session: session,
      memberships: memberships,
      selected_membership: selected,
      organization: selected && selected.organization,
      role: selected && selected.role
    }
  end

  defp eligible_user_for_update(nil), do: nil

  defp eligible_user_for_update(email) do
    user =
      Repo.one(
        from user in User,
          where: user.email == ^email,
          lock: "FOR UPDATE"
      )

    case user do
      %User{} = user ->
        if Repo.exists?(
             from membership in OrganizationMembership,
               where: membership.user_id == ^user.id and is_nil(membership.deactivated_at)
           ),
           do: user,
           else: nil

      nil ->
        nil
    end
  end

  defp throttled?(user_id, now) do
    hour_ago = DateTime.add(now, -3600, :second)

    sent_times =
      Repo.all(
        from challenge in BrowserLoginChallenge,
          where:
            challenge.user_id == ^user_id and not is_nil(challenge.sent_at) and
              challenge.sent_at > ^hour_ago,
          order_by: [desc: challenge.sent_at],
          select: challenge.sent_at
      )

    case sent_times do
      [latest | _] ->
        DateTime.diff(now, latest, :second) < @request_cooldown_seconds or
          length(sent_times) >= @hourly_request_limit

      [] ->
        false
    end
  end

  defp revoke_open_challenges(user_id, now) do
    Repo.update_all(
      from(challenge in BrowserLoginChallenge,
        where:
          challenge.user_id == ^user_id and is_nil(challenge.consumed_at) and
            is_nil(challenge.revoked_at)
      ),
      set: [revoked_at: now, updated_at: now]
    )
  end

  defp active_memberships(user_id) do
    Repo.all(
      from membership in OrganizationMembership,
        join: organization in assoc(membership, :organization),
        where: membership.user_id == ^user_id and is_nil(membership.deactivated_at),
        preload: [organization: organization],
        order_by: [asc: organization.name, asc: membership.id]
    )
  end

  defp active_membership(user_id, membership_id) do
    Repo.one(
      from membership in OrganizationMembership,
        where:
          membership.id == ^membership_id and membership.user_id == ^user_id and
            is_nil(membership.deactivated_at)
    )
  end

  defp selection_inactive?(%BrowserSession{selected_membership_id: nil}, _memberships), do: false

  defp selection_inactive?(session, memberships) do
    not Enum.any?(memberships, &(&1.id == session.selected_membership_id))
  end

  defp valid_challenge?(challenge, raw_token, now) do
    is_nil(challenge.consumed_at) and is_nil(challenge.revoked_at) and
      not is_nil(challenge.sent_at) and
      DateTime.after?(DateTime.add(challenge.sent_at, @challenge_lifetime_seconds, :second), now) and
      digest_matches?(challenge.token_digest, raw_token)
  end

  defp valid_session?(session, raw_token, now) do
    is_nil(session.revoked_at) and DateTime.after?(session.expires_at, now) and
      digest_matches?(session.token_digest, raw_token)
  end

  defp reissue_due?(session, now) do
    DateTime.diff(now, session.inserted_at, :second) >= @session_reissue_seconds
  end

  defp token_attrs(prefix) do
    public_id = Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)
    secret = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    raw_token = "#{prefix}_#{public_id}_#{secret}"

    {raw_token, %{public_id: public_id, token_digest: :crypto.hash(:sha256, raw_token)}}
  end

  defp digest_matches?(stored_digest, raw_token) when is_binary(stored_digest) do
    provided_digest = :crypto.hash(:sha256, raw_token)

    byte_size(provided_digest) == byte_size(stored_digest) and
      :crypto.hash_equals(provided_digest, stored_digest)
  end

  defp digest_matches?(_stored_digest, _raw_token), do: false

  defp dummy_token_work do
    dummy = :crypto.strong_rand_bytes(32)
    :crypto.hash(:sha256, dummy)
  end

  defp login_challenge_for_update(challenge_id) do
    with {:ok, challenge_id} <- Ecto.UUID.cast(challenge_id) do
      Repo.one(
        from challenge in BrowserLoginChallenge,
          where: challenge.id == ^challenge_id,
          lock: "FOR UPDATE"
      )
    else
      :error -> nil
    end
  end

  defp challenge_by_public_id_for_update(public_id) do
    Repo.one(
      from challenge in BrowserLoginChallenge,
        where: challenge.public_id == ^public_id,
        lock: "FOR UPDATE"
    )
  end

  defp session_by_public_id_for_update(public_id) do
    Repo.one(
      from session in BrowserSession,
        where: session.public_id == ^public_id,
        lock: "FOR UPDATE"
    )
  end

  defp insert_event!(session, action, metadata \\ %{}) do
    %UserAuthEvent{}
    |> UserAuthEvent.changeset(%{
      user_id: session.user_id,
      browser_session_id: session.id,
      action: action,
      metadata: metadata
    })
    |> Repo.insert!()
  end

  defp normalize_email(email) when is_binary(email), do: User.normalize_email(email)
  defp normalize_email(_email), do: nil

  defp now(opts), do: Keyword.get(opts, :now, DateTime.utc_now(:microsecond))

  defp unwrap_transaction({:ok, value}), do: {:ok, value}
  defp unwrap_transaction({:error, reason}), do: {:error, reason}
end
