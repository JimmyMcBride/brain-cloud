defmodule BrainCloud.Accounts.AuditEvent do
  use Ecto.Schema

  import Ecto.Changeset

  @actions ~w(
    identity.bootstrap
    membership.create
    membership.role_change
    membership.deactivate
    membership.reactivate
    invitation.create
    invitation.revoke
    invitation.accept
    invitation.delivery_requested
    invitation.delivery_sent
    invitation.delivery_failed
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
    agent.create
    agent.rename
    agent.deactivate
    agent.reactivate
    agent_token.create
    agent_token.revoke
    agent_project_access.grant
    agent_project_access.change
    agent_project_access.revoke
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
    belongs_to :actor_agent, BrainCloud.Agents.Agent
    belongs_to :api_token, BrainCloud.Accounts.ApiToken

    timestamps(updated_at: false)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :organization_id,
      :actor_user_id,
      :actor_agent_id,
      :api_token_id,
      :action,
      :resource_type,
      :resource_id,
      :metadata
    ])
    |> validate_required([:organization_id, :action, :metadata])
    |> validate_actor()
    |> validate_inclusion(:action, @actions)
    |> foreign_key_constraint(:organization_id)
    |> foreign_key_constraint(:actor_user_id)
    |> foreign_key_constraint(:actor_agent_id, name: :audit_events_actor_agent_tenant_fkey)
    |> foreign_key_constraint(:api_token_id)
    |> check_constraint(:actor_user_id, name: :audit_events_exactly_one_actor_check)
  end

  defp validate_actor(changeset) do
    case {get_field(changeset, :actor_user_id), get_field(changeset, :actor_agent_id)} do
      {nil, nil} ->
        add_error(changeset, :actor_user_id, "exactly one actor is required")

      {user_id, agent_id} when not is_nil(user_id) and not is_nil(agent_id) ->
        add_error(changeset, :actor_user_id, "exactly one actor is required")

      _one_actor ->
        changeset
    end
  end
end
