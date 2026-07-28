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
      membership = token.membership

      {:ok,
       %AuthContext{
         user_id: membership.user_id,
         organization_id: membership.organization_id,
         membership_id: membership.id,
         role: membership.role,
         api_token_id: token.id,
         scopes: token.scopes
       }}
    else
      _invalid -> {:error, :unauthorized}
    end
  end

  def authenticate(_raw_token), do: {:error, :unauthorized}

  def authorized?(%AuthContext{scopes: scopes}, scope), do: Scopes.allowed?(scopes, scope)

  def audit_changeset(
        %AuthContext{} = auth,
        action,
        resource_type,
        resource_id,
        metadata \\ %{}
      ) do
    AuditEvent.changeset(%AuditEvent{}, %{
      organization_id: auth.organization_id,
      actor_user_id: auth.user_id,
      api_token_id: auth.api_token_id,
      action: action,
      resource_type: resource_type,
      resource_id: resource_id,
      metadata: metadata
    })
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
        membership_id
      )

    case Repo.insert(changeset) do
      {:ok, token} -> {:ok, {token, raw_token}}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp token_changeset(attrs, membership_id) do
    attrs = Map.new(attrs)

    ApiToken.changeset(%ApiToken{}, %{
      membership_id: membership_id,
      public_id: attribute(attrs, :public_id),
      token_digest: attribute(attrs, :token_digest),
      name: attribute(attrs, :name),
      scopes: attribute(attrs, :scopes),
      expires_at: attribute(attrs, :expires_at),
      bootstrap: attribute(attrs, :bootstrap) || false
    })
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
      token -> Repo.preload(token, membership: [:user, :organization])
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
    membership_active? = is_nil(token.membership.deactivated_at)
    not_revoked? = is_nil(token.revoked_at)

    not_expired? =
      is_nil(token.expires_at) or DateTime.after?(token.expires_at, DateTime.utc_now())

    provided_digest = :crypto.hash(:sha256, raw_token)

    digest_matches? =
      byte_size(provided_digest) == byte_size(token.token_digest) and
        :crypto.hash_equals(provided_digest, token.token_digest)

    membership_active? and not_revoked? and not_expired? and digest_matches?
  end

  defp unwrap_transaction({:ok, value}), do: {:ok, value}
  defp unwrap_transaction({:error, reason}), do: {:error, reason}

  defp attribute(attrs, key) do
    Map.get(attrs, key, Map.get(attrs, Atom.to_string(key)))
  end

  defp normalize(value, function) when is_binary(value), do: function.(value)
  defp normalize(_value, _function), do: nil
end
