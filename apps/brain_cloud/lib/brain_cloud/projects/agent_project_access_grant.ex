defmodule BrainCloud.Projects.AgentProjectAccessGrant do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "agent_project_access_grants" do
    field :access, :string, default: "reader"
    belongs_to :organization, BrainCloud.Accounts.Organization
    belongs_to :project, BrainCloud.Projects.Project
    belongs_to :agent, BrainCloud.Agents.Agent
    timestamps()
  end

  def changeset(grant, attrs) do
    grant
    |> cast(attrs, [:organization_id, :project_id, :agent_id, :access])
    |> validate_required([:organization_id, :project_id, :agent_id, :access])
    |> validate_inclusion(:access, ["reader", "editor"])
    |> foreign_key_constraint(:organization_id)
    |> foreign_key_constraint(:project_id,
      name: :agent_project_access_grants_project_tenant_fkey
    )
    |> foreign_key_constraint(:agent_id, name: :agent_project_access_grants_agent_tenant_fkey)
    |> unique_constraint([:project_id, :agent_id],
      name: :agent_project_access_grants_project_agent_index
    )
    |> check_constraint(:access, name: :agent_project_access_grants_access_check)
  end
end
