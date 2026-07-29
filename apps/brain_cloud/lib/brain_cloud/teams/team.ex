defmodule BrainCloud.Teams.Team do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "teams" do
    field :name, :string
    field :deactivated_at, :utc_datetime_usec
    belongs_to :organization, BrainCloud.Accounts.Organization
    timestamps()
  end

  def changeset(team, attrs) do
    team
    |> cast(attrs, [:organization_id, :name, :deactivated_at])
    |> update_change(:name, &String.trim/1)
    |> validate_required([:organization_id, :name])
    |> validate_length(:name, max: 100)
    |> foreign_key_constraint(:organization_id)
    |> unique_constraint(:name, name: :teams_organization_lower_name_index)
  end
end
