defmodule BrainCloud.Accounts.OrganizationInvitation do
  use Ecto.Schema

  import Ecto.Changeset

  alias BrainCloud.Accounts.Scopes
  alias BrainCloud.Accounts.User

  @maximum_lifetime_seconds 7 * 24 * 60 * 60
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "organization_invitations" do
    field :email, :string
    field :display_name, :string
    field :role, :string, default: "member"
    field :scopes, {:array, :string}, default: []
    field :public_id, :string
    field :secret_digest, :binary, redact: true
    field :delivery_state, :string, default: "manual"
    field :delivery_generation, :binary_id
    field :expires_at, :utc_datetime_usec
    field :accepted_at, :utc_datetime_usec
    field :revoked_at, :utc_datetime_usec

    belongs_to :organization, BrainCloud.Accounts.Organization

    belongs_to :created_by_membership, BrainCloud.Accounts.OrganizationMembership
    belongs_to :accepted_membership, BrainCloud.Accounts.OrganizationMembership

    timestamps()
  end

  def create_changeset(invitation, attrs, now \\ DateTime.utc_now(:microsecond)) do
    invitation
    |> cast(attrs, [
      :organization_id,
      :created_by_membership_id,
      :email,
      :display_name,
      :role,
      :scopes,
      :public_id,
      :secret_digest,
      :expires_at
    ])
    |> update_change(:email, &User.normalize_email/1)
    |> update_change(:display_name, &String.trim/1)
    |> update_change(:scopes, &Enum.uniq/1)
    |> validate_required([
      :organization_id,
      :created_by_membership_id,
      :email,
      :display_name,
      :role,
      :scopes,
      :public_id,
      :secret_digest,
      :expires_at
    ])
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+$/)
    |> validate_length(:email, max: 254)
    |> validate_length(:display_name, min: 1, max: 120)
    |> validate_inclusion(:role, ["member"])
    |> validate_subset(:scopes, Scopes.all())
    |> validate_length(:public_id, is: 32)
    |> validate_expiry(now)
    |> foreign_key_constraint(:organization_id)
    |> foreign_key_constraint(:created_by_membership_id,
      name: :organization_invitations_creator_tenant_fkey
    )
    |> unique_constraint(:public_id)
    |> unique_constraint([:organization_id, :email],
      name: :organization_invitations_unresolved_email_index
    )
    |> check_constraint(:role, name: :organization_invitations_role_check)
    |> check_constraint(:email, name: :organization_invitations_normalized_email_check)
    |> check_constraint(:public_id, name: :organization_invitations_public_id_length_check)
    |> check_constraint(:secret_digest, name: :organization_invitations_digest_length_check)
  end

  def status(%__MODULE__{} = invitation, now \\ DateTime.utc_now()) do
    cond do
      invitation.accepted_at -> "accepted"
      invitation.revoked_at -> "revoked"
      not DateTime.after?(invitation.expires_at, now) -> "expired"
      true -> "pending"
    end
  end

  def maximum_lifetime_seconds, do: @maximum_lifetime_seconds

  defp validate_expiry(changeset, now) do
    validate_change(changeset, :expires_at, fn :expires_at, expires_at ->
      maximum = DateTime.add(now, @maximum_lifetime_seconds, :second)

      cond do
        not DateTime.after?(expires_at, now) ->
          [expires_at: "must be in the future"]

        DateTime.after?(expires_at, maximum) ->
          [expires_at: "must be no more than seven days in the future"]

        true ->
          []
      end
    end)
  end
end
