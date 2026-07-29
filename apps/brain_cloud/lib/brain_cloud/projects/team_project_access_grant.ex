defmodule BrainCloud.Projects.TeamProjectAccessGrant do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "team_project_access_grants" do
    field :access, :string
    belongs_to :organization, BrainCloud.Accounts.Organization
    belongs_to :project, BrainCloud.Projects.Project
    belongs_to :team, BrainCloud.Teams.Team
    timestamps()
  end

  def changeset(grant, attrs) do
    grant
    |> cast(attrs, [:organization_id, :project_id, :team_id, :access])
    |> validate_required([:organization_id, :project_id, :team_id, :access])
    |> validate_inclusion(:access, ~w(reader editor))
    |> foreign_key_constraint(:project_id,
      name: :team_project_access_grants_project_tenant_fkey
    )
    |> foreign_key_constraint(:team_id, name: :team_project_access_grants_team_tenant_fkey)
    |> unique_constraint([:project_id, :team_id],
      name: :team_project_access_grants_project_team_index
    )
    |> check_constraint(:access, name: :team_project_access_grants_access_check)
  end
end
