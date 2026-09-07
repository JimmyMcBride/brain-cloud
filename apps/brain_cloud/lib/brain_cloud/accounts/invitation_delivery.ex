defmodule BrainCloud.Accounts.InvitationDelivery do
  @moduledoc """
  Browser-owner invitation delivery reservations. SMTP belongs to the web boundary
  and must run after reservation commits, before generation-checked finalization.
  """
  import Ecto.Query
  alias BrainCloud.Repo
  alias BrainCloud.Accounts
  alias BrainCloud.Accounts.{AuditEvent, OrganizationInvitation, OrganizationMembership}
  alias BrainCloud.Accounts.InvitationDeliveryAttempt, as: Attempt
  alias Ecto.Changeset

  def create(raw_session, attrs) do
    now = DateTime.utc_now(:microsecond)

    with_owner(raw_session, fn scope ->
      changeset =
        OrganizationInvitation.create_changeset(
          %OrganizationInvitation{},
          %{
            email: Map.get(attrs, "email"),
            display_name: Map.get(attrs, "display_name"),
            organization_id: scope.organization.id,
            created_by_membership_id: scope.selected_membership.id,
            role: "member",
            scopes: ["memory.read", "search.keyword"],
            expires_at: DateTime.add(now, 7 * 24 * 3600, :second),
            public_id: Base.encode16(:crypto.strong_rand_bytes(16), case: :lower),
            secret_digest: :crypto.strong_rand_bytes(32)
          },
          now
        )

      case Changeset.apply_action(changeset, :insert) do
        {:error, invalid} ->
          Repo.rollback(invalid)

        {:ok, valid} ->
          Ecto.Adapters.SQL.query!(
            Repo,
            "SELECT pg_advisory_xact_lock(hashtextextended($1, 0))",
            [valid.email]
          )

          if Repo.exists?(
               from m in OrganizationMembership,
                 join: u in assoc(m, :user),
                 where: m.organization_id == ^valid.organization_id and u.email == ^valid.email
             ),
             do: Repo.rollback(:membership_exists)

          if Repo.exists?(
               from i in OrganizationInvitation,
                 where:
                   i.organization_id == ^valid.organization_id and i.email == ^valid.email and
                     is_nil(i.accepted_at) and is_nil(i.revoked_at)
             ),
             do: Repo.rollback(:invitation_exists)

          invitation = Repo.insert!(changeset)

          audit!(scope.user.id, invitation, "invitation.create", %{
            "scopes" => invitation.scopes,
            "expires_at" => DateTime.to_iso8601(invitation.expires_at)
          })

          reserve_locked(scope, invitation, now)
      end
    end)
  end

  def list(raw_session) do
    with_owner(raw_session, fn scope ->
      Repo.all(
        from i in OrganizationInvitation,
          where:
            i.organization_id == ^scope.organization.id and is_nil(i.accepted_at) and
              is_nil(i.revoked_at),
          order_by: [desc: i.inserted_at, asc: i.id]
      )
    end)
  end

  def reserve(raw_session, invitation_id, opts \\ []) do
    now = Keyword.get(opts, :now, DateTime.utc_now(:microsecond))

    with_owner(raw_session, fn scope ->
      invitation = locked_invitation(scope.organization.id, invitation_id)
      require_pending!(invitation, now)
      reserve_locked(scope, invitation, now)
    end)
  end

  def revoke(raw_session, invitation_id) do
    with_owner(raw_session, fn scope ->
      invitation = locked_invitation(scope.organization.id, invitation_id)
      if is_nil(invitation), do: Repo.rollback(:invitation_not_found)

      if is_nil(invitation.revoked_at) and is_nil(invitation.accepted_at) do
        invitation
        |> Changeset.change(revoked_at: DateTime.utc_now(:microsecond))
        |> Repo.update!()

        audit!(scope.user.id, invitation, "invitation.revoke", %{})
      end

      :ok
    end)
  end

  def finish(attempt_id, outcome) when outcome in [:sent, :failed] do
    Repo.transaction(fn ->
      attempt = Repo.get!(Attempt, attempt_id)
      invitation = locked_invitation(attempt.organization_id, attempt.invitation_id)
      now = DateTime.utc_now(:microsecond)

      if invitation.delivery_generation == attempt.id and invitation.delivery_state == "sending" and
           OrganizationInvitation.status(invitation, now) == "pending" do
        invitation |> Changeset.change(delivery_state: Atom.to_string(outcome)) |> Repo.update!()
        metadata = %{"generation_id" => attempt.id}

        metadata =
          if outcome == :failed,
            do: Map.put(metadata, "failure_category", "delivery_failed"),
            else: metadata

        audit!(
          attempt.requested_by_user_id,
          invitation,
          "invitation.delivery_#{outcome}",
          metadata
        )

        outcome
      else
        :stale
      end
    end)
  end

  defp reserve_locked(scope, invitation, now) do
    # Active owners are already locked in ID order. The organization row serializes
    # quota reservations across invitations and application processes.
    Repo.one!(
      from o in BrainCloud.Accounts.Organization,
        where: o.id == ^scope.organization.id,
        lock: "FOR UPDATE"
    )

    hour_ago = DateTime.add(now, -3600, :second)

    attempts =
      Repo.all(
        from a in Attempt,
          where: a.organization_id == ^scope.organization.id and a.inserted_at > ^hour_ago,
          order_by: [desc: a.inserted_at]
      )

    own = Enum.filter(attempts, &(&1.invitation_id == invitation.id))
    waits = [quota_wait(attempts, 20, now), quota_wait(own, 5, now)]

    waits =
      case own do
        [latest | _] -> [60 - DateTime.diff(now, latest.inserted_at, :second) | waits]
        [] -> waits
      end

    wait = Enum.max([0 | waits])
    if wait > 0, do: Repo.rollback({:throttled, wait})

    # Retain exactly the rolling window; immutable audit events retain provenance.
    Repo.delete_all(
      from a in Attempt,
        where:
          a.organization_id == ^scope.organization.id and a.inserted_at <= ^hour_ago and
            a.id not in subquery(
              from i in OrganizationInvitation,
                where: not is_nil(i.delivery_generation),
                select: i.delivery_generation
            )
    )

    attempt =
      Repo.insert!(%Attempt{
        organization_id: invitation.organization_id,
        invitation_id: invitation.id,
        requested_by_user_id: scope.user.id,
        inserted_at: now
      })

    secret = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    token = "bci1_#{invitation.public_id}_#{secret}"

    invitation =
      invitation
      |> Changeset.change(
        delivery_generation: attempt.id,
        delivery_state: "sending",
        secret_digest: :crypto.hash(:sha256, token)
      )
      |> Repo.update!()

    audit!(scope.user.id, invitation, "invitation.delivery_requested", %{
      "generation_id" => attempt.id
    })

    %{attempt: attempt, invitation: invitation, token: token}
  end

  defp quota_wait(attempts, limit, now) when length(attempts) >= limit do
    attempt = Enum.at(attempts, limit - 1)
    max(1, 3600 - DateTime.diff(now, attempt.inserted_at, :second))
  end

  defp quota_wait(_, _, _), do: 0

  defp with_owner(raw_session, fun) do
    Repo.transaction(fn ->
      with {:ok, scope, nil} <- Accounts.authenticate_browser_session(raw_session, rotate: false),
           %{id: membership_id} <- scope.selected_membership do
        owners =
          Repo.all(
            from m in OrganizationMembership,
              where:
                m.organization_id == ^scope.organization.id and m.role == "owner" and
                  is_nil(m.deactivated_at),
              order_by: [asc: m.id],
              lock: "FOR UPDATE"
          )

        if Enum.any?(owners, &(&1.id == membership_id and &1.user_id == scope.user.id)),
          do: fun.(scope),
          else: Repo.rollback(:invitation_not_found)
      else
        _ -> Repo.rollback(:unauthorized)
      end
    end)
  end

  defp locked_invitation(organization_id, id) do
    case Ecto.UUID.cast(id) do
      {:ok, id} ->
        Repo.one(
          from i in OrganizationInvitation,
            where: i.id == ^id and i.organization_id == ^organization_id,
            lock: "FOR UPDATE"
        )

      :error ->
        nil
    end
  end

  defp require_pending!(nil, _now), do: Repo.rollback(:invitation_not_found)

  defp require_pending!(invitation, now) do
    if OrganizationInvitation.status(invitation, now) != "pending",
      do: Repo.rollback(:invitation_not_found)
  end

  defp audit!(user_id, invitation, action, metadata) do
    %AuditEvent{}
    |> AuditEvent.changeset(%{
      organization_id: invitation.organization_id,
      actor_user_id: user_id,
      action: action,
      resource_type: "organization_invitation",
      resource_id: invitation.id,
      metadata: metadata
    })
    |> Repo.insert!()
  end
end
