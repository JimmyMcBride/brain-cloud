defmodule BrainCloud.Accounts.AuditEvent do
  use Ecto.Schema

  import Ecto.Changeset

  @actions ~w(
    identity.bootstrap
    membership.create
    membership.role_change
    membership.deactivate
    membership.reactivate
    token.create
    token.revoke
    project.create
    project_access.grant
    project_access.change
    project_access.revoke
    team.create
    team.rename
    team.deactivate
    team.reactivate
    team_membership.add
    team_membership.remove
    team_project_access.grant
    team_project_access.change
    team_project_access.revoke
    memory.create
  )
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "audit_events" do
    field :action, :string
    field :resource_type, :string
    field :resource_id, :binary_id
    field :metadata, :map, default: %{}

    belongs_to :organization, BrainCloud.Accounts.Organization
    belongs_to :actor_user, BrainCloud.Accounts.User
    belongs_to :api_token, BrainCloud.Accounts.ApiToken

    timestamps(updated_at: false)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :organization_id,
      :actor_user_id,
      :api_token_id,
      :action,
      :resource_type,
      :resource_id,
      :metadata
    ])
    |> validate_required([:organization_id, :actor_user_id, :action, :metadata])
    |> validate_inclusion(:action, @actions)
    |> foreign_key_constraint(:organization_id)
    |> foreign_key_constraint(:actor_user_id)
    |> foreign_key_constraint(:api_token_id)
  end
end
