defmodule BrainCloud.Accounts do
  @moduledoc """
  Owns production API identities, organization memberships, credentials, and audit events.
  """

  import Ecto.Query

  alias BrainCloud.Accounts.ApiToken
  alias BrainCloud.Accounts.AuditEvent
  alias BrainCloud.Accounts.AuthContext
  alias BrainCloud.Accounts.Organization
  alias BrainCloud.Accounts.OrganizationMembership
  alias BrainCloud.Accounts.Scopes
  alias BrainCloud.Accounts.User
  alias BrainCloud.Agents.Agent
  alias BrainCloud.Repo
  alias Ecto.Changeset
  alias Ecto.Multi

  @phase_one_organization_id "00000000-0000-0000-0000-0000000000f1"
  @token_pattern ~r/\Abc1_([0-9a-f]{32})_([A-Za-z0-9_-]{43})\z/
  @validation_public_id String.duplicate("0", 32)
  @validation_digest :binary.copy(<<0>>, 32)

  def bootstrap_owner(attrs, opts \\ []) do
    attrs = Map.new(attrs)
    adopt_phase_one? = Keyword.get(opts, :adopt_phase_one, false)
    rotate_token? = Keyword.get(opts, :rotate_token, false)

    Repo.transaction(fn ->
      with {:ok, user} <- find_or_create_user(attrs),
           {:ok, organization} <- find_or_create_organization(attrs, adopt_phase_one?),
           {:ok, membership} <- ensure_owner_membership(user, organization),
           {:ok, result} <- ensure_bootstrap_token(user, organization, membership, rotate_token?) do
        Map.merge(result, %{
          user: user,
          organization: organization,
          membership: membership
        })
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> unwrap_transaction()
  end

  def create_organization_membership(%AuthContext{} = auth, attrs) do
    attrs = Map.new(attrs)

    with :ok <- authorize_membership_management(auth),
         {:ok, user_attrs} <- validate_membership_user(attrs) do
      Repo.transaction(fn ->
        with {:ok, user} <- find_or_create_membership_user(user_attrs),
             :ok <- ensure_membership_absent(user.id, auth.organization_id),
             {:ok, membership} <-
               %OrganizationMembership{}
               |> OrganizationMembership.changeset(%{
                 user_id: user.id,
                 organization_id: auth.organization_id,
                 role: attribute(attrs, :role)
               })
               |> Repo.insert(),
             {:ok, _event} <-
               audit_changeset(
                 auth,
                 "membership.create",
                 "organization_membership",
                 membership.id,
                 %{"role" => membership.role, "user_id" => user.id}
               )
               |> Repo.insert() do
          Repo.preload(membership, :user)
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
      |> unwrap_transaction()
    end
  end

  def list_organization_memberships(%AuthContext{} = auth) do
    with :ok <- authorize_membership_management(auth) do
      memberships =
        Repo.all(
          from membership in OrganizationMembership,
            join: user in assoc(membership, :user),
            where: membership.organization_id == ^auth.organization_id,
            preload: [user: user],
            order_by: [asc: membership.inserted_at, asc: membership.id]
        )

      {:ok, memberships}
    end
  end

  def update_organization_membership_role(%AuthContext{} = auth, membership_id, role) do
    with :ok <- authorize_membership_management(auth),
         {:ok, membership_id} <- Ecto.UUID.cast(membership_id) do
      Repo.transaction(fn ->
        active_owners = lock_active_owners(auth.organization_id)

        with %OrganizationMembership{} = membership <-
               organization_membership_for_update(auth.organization_id, membership_id),
             role_changeset = OrganizationMembership.changeset(membership, %{role: role}),
             {:ok, validated_membership} <-
               Changeset.apply_action(role_changeset, :update),
             :ok <- preserve_active_owner(membership, validated_membership.role, active_owners),
             {:ok, updated_membership} <- Repo.update(role_changeset),
             :ok <- revoke_tokens_after_demotion(membership, updated_membership),
             {:ok, _event} <-
               audit_role_change(auth, membership, updated_membership) do
          Repo.preload(updated_membership, :user)
        else
          nil -> Repo.rollback(:membership_not_found)
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
      |> unwrap_transaction()
    else
      :error -> {:error, :membership_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def deactivate_organization_membership(%AuthContext{} = auth, membership_id) do
    with :ok <- authorize_membership_management(auth),
         {:ok, membership_id} <- Ecto.UUID.cast(membership_id) do
      Repo.transaction(fn ->
        active_owners = lock_active_owners(auth.organization_id)

        case organization_membership_for_update(auth.organization_id, membership_id) do
          nil ->
            Repo.rollback(:membership_not_found)

          %OrganizationMembership{deactivated_at: deactivated_at} = membership
          when not is_nil(deactivated_at) ->
            Repo.preload(membership, :user)

          %OrganizationMembership{} = membership ->
            with :ok <- preserve_active_owner(membership, nil, active_owners),
                 {:ok, deactivated_membership} <-
                   membership
                   |> Changeset.change(deactivated_at: DateTime.utc_now(:microsecond))
                   |> Repo.update(),
                 {_count, _tokens} <- revoke_membership_tokens(membership.id),
                 {:ok, _event} <-
                   audit_changeset(
                     auth,
                     "membership.deactivate",
                     "organization_membership",
                     membership.id,
                     %{"role" => membership.role}
                   )
                   |> Repo.insert() do
              Repo.preload(deactivated_membership, :user)
            else
              {:error, reason} -> Repo.rollback(reason)
            end
        end
      end)
      |> unwrap_transaction()
    else
      :error -> {:error, :membership_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def reactivate_organization_membership(%AuthContext{} = auth, membership_id) do
    with :ok <- authorize_membership_management(auth),
         {:ok, membership_id} <- Ecto.UUID.cast(membership_id) do
      Repo.transaction(fn ->
        case organization_membership_for_update(auth.organization_id, membership_id) do
          nil ->
            Repo.rollback(:membership_not_found)

          %OrganizationMembership{deactivated_at: nil} = membership ->
            Repo.preload(membership, :user)

          %OrganizationMembership{} = membership ->
            with {:ok, reactivated_membership} <-
                   membership
                   |> Changeset.change(deactivated_at: nil)
                   |> Repo.update(),
                 {:ok, _event} <-
                   audit_changeset(
                     auth,
                     "membership.reactivate",
                     "organization_membership",
                     membership.id,
                     %{"role" => membership.role}
                   )
                   |> Repo.insert() do
              Repo.preload(reactivated_membership, :user)
            else
              {:error, reason} -> Repo.rollback(reason)
            end
        end
      end)
      |> unwrap_transaction()
    else
      :error -> {:error, :membership_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def create_membership_api_token(%AuthContext{} = auth, membership_id, attrs) do
    attrs = Map.new(attrs)

    with :ok <- authorize_target_token_management(auth),
         {:ok, membership_id} <- Ecto.UUID.cast(membership_id) do
      Repo.transaction(fn ->
        case organization_membership_for_update(auth.organization_id, membership_id) do
          nil ->
            Repo.rollback(:membership_not_found)

          %OrganizationMembership{deactivated_at: deactivated_at}
          when not is_nil(deactivated_at) ->
            Repo.rollback(:membership_inactive)

          %OrganizationMembership{} = membership ->
            with :ok <- validate_target_token_scopes(auth, membership, attrs),
                 {:ok, {token, raw_token}} <- issue_token(membership.id, attrs, false),
                 {:ok, _event} <-
                   audit_changeset(auth, "token.create", "api_token", token.id, %{
                     "name" => token.name,
                     "scopes" => token.scopes,
                     "target_membership_id" => membership.id
                   })
                   |> Repo.insert() do
              {token, raw_token}
            else
              {:error, reason} -> Repo.rollback(reason)
            end
        end
      end)
      |> case do
        {:ok, {token, raw_token}} -> {:ok, token, raw_token}
        {:error, reason} -> {:error, reason}
      end
    else
      :error -> {:error, :membership_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def create_api_token(%AuthContext{} = auth, attrs) do
    attrs = Map.new(attrs)

    with :ok <- authorize_token_management(auth),
         scopes when is_list(scopes) <- attribute(attrs, :scopes),
         true <- Scopes.subset?(scopes, auth.scopes) do
      Multi.new()
      |> Multi.run(:issued_token, fn _repo, _changes ->
        issue_token(auth.membership_id, attrs, false)
      end)
      |> Multi.insert(:audit_event, fn %{issued_token: {token, _raw_token}} ->
        audit_changeset(auth, "token.create", "api_token", token.id, %{
          "name" => token.name,
          "scopes" => token.scopes
        })
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{issued_token: {token, raw_token}}} -> {:ok, token, raw_token}
        {:error, :issued_token, reason, _changes} -> {:error, reason}
        {:error, _operation, changeset, _changes} -> {:error, changeset}
      end
    else
      nil -> {:error, validation_token_changeset(attrs, auth.membership_id)}
      :error -> {:error, validation_token_changeset(attrs, auth.membership_id)}
      false -> {:error, scope_subset_changeset(attrs, auth.membership_id)}
      {:error, reason} -> {:error, reason}
    end
  end

  def list_api_tokens(%AuthContext{} = auth) do
    with :ok <- authorize_token_management(auth) do
      tokens =
        Repo.all(
          from token in ApiToken,
            join: membership in OrganizationMembership,
            on: membership.id == token.membership_id,
            where: membership.organization_id == ^auth.organization_id,
            order_by: [asc: token.inserted_at, asc: token.id]
        )

      {:ok, tokens}
    end
  end

  def revoke_api_token(%AuthContext{} = auth, token_id) do
    with :ok <- authorize_token_management(auth),
         {:ok, token_id} <- Ecto.UUID.cast(token_id),
         %ApiToken{} = token <- organization_token(auth.organization_id, token_id) do
      if token.revoked_at do
        {:ok, token}
      else
        revoked_at = DateTime.utc_now(:microsecond)

        Multi.new()
        |> Multi.update(:token, Changeset.change(token, revoked_at: revoked_at))
        |> Multi.insert(
          :audit_event,
          audit_changeset(auth, "token.revoke", "api_token", token.id)
        )
        |> Repo.transaction()
        |> case do
          {:ok, %{token: revoked_token}} -> {:ok, revoked_token}
          {:error, _operation, changeset, _changes} -> {:error, changeset}
        end
      end
    else
      :error -> {:error, :token_not_found}
      nil -> {:error, :token_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def authenticate(raw_token) when is_binary(raw_token) do
    with [_, public_id, _secret] <- Regex.run(@token_pattern, raw_token),
         %ApiToken{} = token <- token_by_public_id(public_id),
         true <- valid_token?(token, raw_token) do
      {:ok, auth_context(token)}
    else
      _invalid -> {:error, :unauthorized}
    end
  end

  def authenticate(_raw_token), do: {:error, :unauthorized}

  def authorized?(%AuthContext{scopes: scopes}, scope), do: Scopes.allowed?(scopes, scope)

  def issue_agent_token(agent_id, attrs) do
    attrs = Map.new(attrs)

    case attribute(attrs, :scopes) do
      scopes when is_list(scopes) ->
        if scopes != [] and
             Scopes.subset?(scopes, ["memory.write", "memory.read", "search.keyword"]) do
          issue_token_for(%{agent_id: agent_id}, attrs, false)
        else
          {:error, agent_scope_changeset(attrs, agent_id)}
        end

      _missing ->
        {:error, agent_validation_token_changeset(attrs, agent_id)}
    end
  end

  def audit_changeset(
        %AuthContext{} = auth,
        action,
        resource_type,
        resource_id,
        metadata \\ %{}
      ) do
    actor =
      case auth.principal_type do
        :human -> %{actor_user_id: auth.user_id}
        :agent -> %{actor_agent_id: auth.agent_id}
      end

    AuditEvent.changeset(
      %AuditEvent{},
      Map.merge(
        %{
          organization_id: auth.organization_id,
          api_token_id: auth.api_token_id,
          action: action,
          resource_type: resource_type,
          resource_id: resource_id,
          metadata: metadata
        },
        actor
      )
    )
  end

  def phase_one_organization_id, do: @phase_one_organization_id

  defp find_or_create_user(attrs) do
    email = attrs |> attribute(:email) |> normalize(&User.normalize_email/1)

    case email && Repo.get_by(User, email: email) do
      %User{} = user ->
        {:ok, user}

      nil ->
        %User{}
        |> User.changeset(%{
          email: email,
          display_name: attribute(attrs, :display_name)
        })
        |> Repo.insert()
    end
  end

  defp validate_membership_user(attrs) do
    changeset =
      User.changeset(%User{}, %{
        email: attribute(attrs, :email),
        display_name: attribute(attrs, :display_name)
      })

    case Changeset.apply_action(changeset, :insert) do
      {:ok, user} -> {:ok, %{email: user.email, display_name: user.display_name}}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp find_or_create_membership_user(attrs) do
    Ecto.Adapters.SQL.query!(
      Repo,
      "SELECT pg_advisory_xact_lock(hashtextextended($1, 0))",
      [attrs.email]
    )

    case Repo.get_by(User, email: attrs.email) do
      %User{} = user ->
        {:ok, lock_user(user.id)}

      nil ->
        with {:ok, user} <-
               %User{}
               |> User.changeset(attrs)
               |> Repo.insert() do
          {:ok, lock_user(user.id)}
        end
    end
  end

  defp lock_user(user_id) do
    Repo.one!(
      from user in User,
        where: user.id == ^user_id,
        lock: "FOR UPDATE"
    )
  end

  defp ensure_membership_absent(user_id, organization_id) do
    case Repo.get_by(OrganizationMembership,
           user_id: user_id,
           organization_id: organization_id
         ) do
      nil -> :ok
      %OrganizationMembership{deactivated_at: nil} -> {:error, :membership_exists}
      %OrganizationMembership{} -> {:error, :membership_inactive}
    end
  end

  defp find_or_create_organization(_attrs, true) do
    case Repo.get(Organization, @phase_one_organization_id) do
      %Organization{} = organization -> {:ok, organization}
      nil -> {:error, :phase_one_organization_not_found}
    end
  end

  defp find_or_create_organization(attrs, false) do
    slug = attrs |> attribute(:organization_slug) |> normalize(&Organization.normalize_slug/1)

    case slug && Repo.get_by(Organization, slug: slug) do
      %Organization{} = organization ->
        {:ok, organization}

      nil ->
        %Organization{}
        |> Organization.changeset(%{
          name: attribute(attrs, :organization_name),
          slug: slug
        })
        |> Repo.insert()
    end
  end

  defp ensure_owner_membership(user, organization) do
    case Repo.get_by(OrganizationMembership,
           user_id: user.id,
           organization_id: organization.id
         ) do
      %OrganizationMembership{} = membership ->
        membership
        |> OrganizationMembership.changeset(%{role: "owner", deactivated_at: nil})
        |> Repo.update()

      nil ->
        %OrganizationMembership{}
        |> OrganizationMembership.changeset(%{
          user_id: user.id,
          organization_id: organization.id,
          role: "owner"
        })
        |> Repo.insert()
    end
  end

  defp ensure_bootstrap_token(user, organization, membership, rotate_token?) do
    case active_bootstrap_token(membership.id) do
      nil ->
        with {:ok, {token, raw_token}} <-
               issue_token(
                 membership.id,
                 %{name: "Bootstrap owner", scopes: Scopes.all()},
                 true
               ),
             {:ok, _event} <-
               %AuditEvent{}
               |> AuditEvent.changeset(%{
                 organization_id: organization.id,
                 actor_user_id: user.id,
                 api_token_id: token.id,
                 action: "identity.bootstrap",
                 resource_type: "organization",
                 resource_id: organization.id,
                 metadata: %{}
               })
               |> Repo.insert() do
          {:ok, %{token: token, raw_token: raw_token, created: true}}
        end

      %ApiToken{} = token when rotate_token? ->
        rotate_bootstrap_token(user, organization, membership, token)

      %ApiToken{} = token ->
        {:ok, %{token: token, raw_token: nil, created: false}}
    end
  end

  defp rotate_bootstrap_token(user, organization, membership, old_token) do
    revoked_at = DateTime.utc_now(:microsecond)

    with {:ok, _revoked_token} <-
           old_token |> Changeset.change(revoked_at: revoked_at) |> Repo.update(),
         {:ok, _event} <-
           bootstrap_audit_changeset(
             user,
             organization,
             old_token,
             "token.revoke",
             %{"reason" => "bootstrap_recovery"}
           )
           |> Repo.insert(),
         {:ok, {new_token, raw_token}} <-
           issue_token(
             membership.id,
             %{name: "Bootstrap owner", scopes: Scopes.all()},
             true
           ),
         {:ok, _event} <-
           bootstrap_audit_changeset(
             user,
             organization,
             new_token,
             "token.create",
             %{"reason" => "bootstrap_recovery"}
           )
           |> Repo.insert() do
      {:ok, %{token: new_token, raw_token: raw_token, created: true}}
    end
  end

  defp bootstrap_audit_changeset(user, organization, token, action, metadata) do
    AuditEvent.changeset(%AuditEvent{}, %{
      organization_id: organization.id,
      actor_user_id: user.id,
      api_token_id: token.id,
      action: action,
      resource_type: "api_token",
      resource_id: token.id,
      metadata: metadata
    })
  end

  defp issue_token(membership_id, attrs, bootstrap?) do
    issue_token_for(%{membership_id: membership_id}, attrs, bootstrap?)
  end

  defp issue_token_for(principal, attrs, bootstrap?) do
    public_id = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
    secret = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    raw_token = "bc1_#{public_id}_#{secret}"

    changeset =
      token_changeset(
        Map.merge(Map.new(attrs), %{
          public_id: public_id,
          token_digest: :crypto.hash(:sha256, raw_token),
          bootstrap: bootstrap?
        }),
        principal
      )

    case Repo.insert(changeset) do
      {:ok, token} -> {:ok, {token, raw_token}}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp token_changeset(attrs, membership_id) when is_binary(membership_id) do
    token_changeset(attrs, %{membership_id: membership_id})
  end

  defp token_changeset(attrs, principal) when is_map(principal) do
    attrs = Map.new(attrs)

    ApiToken.changeset(
      %ApiToken{},
      Map.merge(principal, %{
        public_id: attribute(attrs, :public_id),
        token_digest: attribute(attrs, :token_digest),
        name: attribute(attrs, :name),
        scopes: attribute(attrs, :scopes),
        expires_at: attribute(attrs, :expires_at),
        bootstrap: attribute(attrs, :bootstrap) || false
      })
    )
  end

  defp scope_subset_changeset(attrs, membership_id) do
    attrs
    |> validation_token_changeset(membership_id)
    |> Changeset.add_error(:scopes, "must be a subset of the current token scopes")
  end

  defp validation_token_changeset(attrs, membership_id) do
    attrs
    |> Map.new()
    |> Map.put(:public_id, @validation_public_id)
    |> Map.put(:token_digest, @validation_digest)
    |> token_changeset(membership_id)
  end

  defp authorize_token_management(%AuthContext{role: "owner"} = auth) do
    if authorized?(auth, "tokens.manage"), do: :ok, else: {:error, :forbidden}
  end

  defp authorize_token_management(_auth), do: {:error, :forbidden}

  defp authorize_membership_management(%AuthContext{role: "owner"} = auth) do
    if authorized?(auth, "members.manage"), do: :ok, else: {:error, :forbidden}
  end

  defp authorize_membership_management(_auth), do: {:error, :forbidden}

  defp authorize_target_token_management(%AuthContext{role: "owner"} = auth) do
    if authorized?(auth, "members.manage") and authorized?(auth, "tokens.manage") do
      :ok
    else
      {:error, :forbidden}
    end
  end

  defp authorize_target_token_management(_auth), do: {:error, :forbidden}

  defp organization_membership_for_update(organization_id, membership_id) do
    Repo.one(
      from membership in OrganizationMembership,
        where:
          membership.id == ^membership_id and
            membership.organization_id == ^organization_id,
        lock: "FOR UPDATE"
    )
  end

  defp lock_active_owners(organization_id) do
    Repo.all(
      from membership in OrganizationMembership,
        where:
          membership.organization_id == ^organization_id and membership.role == "owner" and
            is_nil(membership.deactivated_at),
        order_by: [asc: membership.id],
        lock: "FOR UPDATE"
    )
  end

  defp preserve_active_owner(
         %OrganizationMembership{role: "owner", deactivated_at: nil},
         next_role,
         [_only_owner]
       )
       when next_role != "owner" and next_role in [nil, "member"] do
    {:error, :last_owner_required}
  end

  defp preserve_active_owner(_membership, _next_role, _active_owners), do: :ok

  defp revoke_tokens_after_demotion(
         %OrganizationMembership{role: "owner"},
         %OrganizationMembership{role: "member"} = membership
       ) do
    revoke_membership_tokens(membership.id)
    :ok
  end

  defp revoke_tokens_after_demotion(_membership, _updated_membership), do: :ok

  defp revoke_membership_tokens(membership_id) do
    now = DateTime.utc_now(:microsecond)

    Repo.update_all(
      from(token in ApiToken,
        where: token.membership_id == ^membership_id and is_nil(token.revoked_at)
      ),
      set: [revoked_at: now, updated_at: now]
    )
  end

  defp audit_role_change(
         _auth,
         %OrganizationMembership{role: role},
         %OrganizationMembership{role: role}
       ),
       do: {:ok, nil}

  defp audit_role_change(auth, membership, updated_membership) do
    audit_changeset(
      auth,
      "membership.role_change",
      "organization_membership",
      membership.id,
      %{"previous_role" => membership.role, "role" => updated_membership.role}
    )
    |> Repo.insert()
  end

  defp validate_target_token_scopes(auth, membership, attrs) do
    case attribute(attrs, :scopes) do
      scopes when is_list(scopes) ->
        cond do
          not Scopes.subset?(scopes, auth.scopes) ->
            {:error, scope_subset_changeset(attrs, membership.id)}

          membership.role == "member" and
              Enum.any?(
                scopes,
                &(&1 in [
                    "members.manage",
                    "projects.manage_access",
                    "teams.manage",
                    "agents.manage",
                    "tokens.manage"
                  ])
              ) ->
            {:error, member_management_scope_changeset(attrs, membership.id)}

          true ->
            :ok
        end

      _missing ->
        {:error, validation_token_changeset(attrs, membership.id)}
    end
  end

  defp member_management_scope_changeset(attrs, membership_id) do
    attrs
    |> validation_token_changeset(membership_id)
    |> Changeset.add_error(:scopes, "cannot include management scopes for a member")
  end

  defp active_bootstrap_token(membership_id) do
    Repo.one(
      from token in ApiToken,
        where:
          token.membership_id == ^membership_id and token.bootstrap == true and
            is_nil(token.revoked_at)
    )
  end

  defp token_by_public_id(public_id) do
    case Repo.get_by(ApiToken, public_id: public_id) do
      nil -> nil
      token -> Repo.preload(token, membership: [:user, :organization], agent: :organization)
    end
  end

  defp organization_token(organization_id, token_id) do
    Repo.one(
      from token in ApiToken,
        join: membership in OrganizationMembership,
        on: membership.id == token.membership_id,
        where: token.id == ^token_id and membership.organization_id == ^organization_id
    )
  end

  defp valid_token?(token, raw_token) do
    principal_active? = principal_active?(token)
    not_revoked? = is_nil(token.revoked_at)

    not_expired? =
      is_nil(token.expires_at) or DateTime.after?(token.expires_at, DateTime.utc_now())

    provided_digest = :crypto.hash(:sha256, raw_token)

    digest_matches? =
      byte_size(provided_digest) == byte_size(token.token_digest) and
        :crypto.hash_equals(provided_digest, token.token_digest)

    principal_active? and not_revoked? and not_expired? and digest_matches?
  end

  defp auth_context(%ApiToken{membership: membership} = token)
       when not is_nil(membership) do
    %AuthContext{
      principal_type: :human,
      principal_id: membership.id,
      user_id: membership.user_id,
      organization_id: membership.organization_id,
      membership_id: membership.id,
      role: membership.role,
      api_token_id: token.id,
      scopes: token.scopes
    }
  end

  defp auth_context(%ApiToken{agent: %Agent{} = agent} = token) do
    %AuthContext{
      principal_type: :agent,
      principal_id: agent.id,
      agent_id: agent.id,
      organization_id: agent.organization_id,
      role: "agent",
      api_token_id: token.id,
      scopes: token.scopes
    }
  end

  defp principal_active?(%ApiToken{membership: membership}) when not is_nil(membership),
    do: is_nil(membership.deactivated_at)

  defp principal_active?(%ApiToken{agent: %Agent{} = agent}),
    do: is_nil(agent.deactivated_at)

  defp principal_active?(_token), do: false

  defp agent_validation_token_changeset(attrs, agent_id) do
    attrs
    |> Map.new()
    |> Map.put(:public_id, @validation_public_id)
    |> Map.put(:token_digest, @validation_digest)
    |> token_changeset(%{agent_id: agent_id})
  end

  defp agent_scope_changeset(attrs, agent_id) do
    attrs
    |> agent_validation_token_changeset(agent_id)
    |> Changeset.add_error(:scopes, "may include only memory.read and search.keyword")
  end

  defp unwrap_transaction({:ok, value}), do: {:ok, value}
  defp unwrap_transaction({:error, reason}), do: {:error, reason}

  defp attribute(attrs, key) do
    Map.get(attrs, key, Map.get(attrs, Atom.to_string(key)))
  end

  defp normalize(value, function) when is_binary(value), do: function.(value)
  defp normalize(_value, _function), do: nil
end
