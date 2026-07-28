defmodule BrainCloud.Accounts.ApiToken do
  use Ecto.Schema

  import Ecto.Changeset

  alias BrainCloud.Accounts.Scopes

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "api_tokens" do
    field :public_id, :string
    field :token_digest, :binary, redact: true
    field :name, :string
    field :scopes, {:array, :string}, default: []
    field :expires_at, :utc_datetime_usec
    field :revoked_at, :utc_datetime_usec
    field :bootstrap, :boolean, default: false

    belongs_to :membership, BrainCloud.Accounts.OrganizationMembership

    timestamps()
  end

  def changeset(token, attrs) do
    token
    |> cast(attrs, [
      :membership_id,
      :public_id,
      :token_digest,
      :name,
      :scopes,
      :expires_at,
      :revoked_at,
      :bootstrap
    ])
    |> update_change(:name, &String.trim/1)
    |> update_change(:scopes, &normalize_scopes/1)
    |> validate_required([:membership_id, :public_id, :token_digest, :name, :scopes])
    |> validate_length(:name, min: 1, max: 120)
    |> validate_length(:public_id, is: 32)
    |> validate_subset(:scopes, Scopes.all())
    |> foreign_key_constraint(:membership_id)
    |> unique_constraint(:public_id)
    |> unique_constraint(:membership_id, name: :api_tokens_active_bootstrap_index)
  end

  defp normalize_scopes(scopes) when is_list(scopes), do: Enum.uniq(scopes)
  defp normalize_scopes(scopes), do: scopes
end
