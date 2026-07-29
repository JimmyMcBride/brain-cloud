defmodule BrainCloud.Projects.ProjectAccessGrant do
  use Ecto.Schema

  import Ecto.Changeset

  @access_levels ~w(reader editor)
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "project_access_grants" do
    field :access, :string

    belongs_to :organization, BrainCloud.Accounts.Organization
    belongs_to :project, BrainCloud.Projects.Project

    belongs_to :organization_membership, BrainCloud.Accounts.OrganizationMembership

    timestamps()
  end

  def changeset(grant, attrs) do
    grant
    |> cast(attrs, [:organization_id, :project_id, :organization_membership_id, :access])
    |> validate_required([:organization_id, :project_id, :organization_membership_id, :access])
    |> validate_inclusion(:access, @access_levels)
    |> foreign_key_constraint(:organization_id)
    |> foreign_key_constraint(:project_id, name: :project_access_grants_project_tenant_fkey)
    |> foreign_key_constraint(:organization_membership_id,
      name: :project_access_grants_membership_tenant_fkey
    )
    |> unique_constraint([:project_id, :organization_membership_id],
      name: :project_access_grants_project_membership_index
    )
    |> check_constraint(:access, name: :project_access_grants_access_check)
  end
end
