defmodule BrainCloud.Teams.TeamMembership do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "team_memberships" do
    belongs_to :organization, BrainCloud.Accounts.Organization
    belongs_to :team, BrainCloud.Teams.Team
    belongs_to :organization_membership, BrainCloud.Accounts.OrganizationMembership
    timestamps()
  end

  def changeset(link, attrs) do
    link
    |> cast(attrs, [:organization_id, :team_id, :organization_membership_id])
    |> validate_required([:organization_id, :team_id, :organization_membership_id])
    |> foreign_key_constraint(:team_id, name: :team_memberships_team_tenant_fkey)
    |> foreign_key_constraint(:organization_membership_id,
      name: :team_memberships_membership_tenant_fkey
    )
    |> unique_constraint([:team_id, :organization_membership_id],
      name: :team_memberships_team_membership_index
    )
  end
end
