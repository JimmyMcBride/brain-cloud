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
    belongs_to :agent, BrainCloud.Agents.Agent

    timestamps()
  end

  def changeset(token, attrs) do
    token
    |> cast(attrs, [
      :membership_id,
      :agent_id,
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
    |> validate_required([:public_id, :token_digest, :name, :scopes])
    |> validate_principal()
    |> validate_length(:name, min: 1, max: 120)
    |> validate_length(:public_id, is: 32)
    |> validate_subset(:scopes, Scopes.all())
    |> foreign_key_constraint(:membership_id)
    |> foreign_key_constraint(:agent_id)
    |> unique_constraint(:public_id)
    |> unique_constraint(:membership_id, name: :api_tokens_active_bootstrap_index)
    |> check_constraint(:membership_id, name: :api_tokens_exactly_one_principal_check)
    |> check_constraint(:bootstrap, name: :api_tokens_agent_not_bootstrap_check)
  end

  defp validate_principal(changeset) do
    membership_id = get_field(changeset, :membership_id)
    agent_id = get_field(changeset, :agent_id)

    cond do
      is_nil(membership_id) and is_nil(agent_id) ->
        add_error(changeset, :membership_id, "exactly one principal is required")

      not is_nil(membership_id) and not is_nil(agent_id) ->
        add_error(changeset, :membership_id, "exactly one principal is required")

      not is_nil(agent_id) and get_field(changeset, :bootstrap) ->
        add_error(changeset, :bootstrap, "cannot be true for an agent credential")

      true ->
        changeset
    end
  end

  defp normalize_scopes(scopes) when is_list(scopes), do: Enum.uniq(scopes)
  defp normalize_scopes(scopes), do: scopes
end
