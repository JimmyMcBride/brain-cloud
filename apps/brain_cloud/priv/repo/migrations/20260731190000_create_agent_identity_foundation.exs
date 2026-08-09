defmodule BrainCloud.Repo.Migrations.CreateAgentIdentityFoundation do
  use Ecto.Migration

  def up do
    create table(:agents, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :restrict),
        null: false

      add :name, :string, null: false
      add :deactivated_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:agents, [:id, :organization_id], name: :agents_id_organization_id_index)

    execute(
      "CREATE UNIQUE INDEX agents_organization_lower_name_index ON agents (organization_id, lower(name))"
    )

    alter table(:api_tokens) do
      modify :membership_id, :binary_id, null: true
      add :agent_id, references(:agents, type: :binary_id, on_delete: :restrict)
    end

    create index(:api_tokens, [:agent_id])

    create constraint(:api_tokens, :api_tokens_exactly_one_principal_check,
             check: "(membership_id IS NOT NULL) <> (agent_id IS NOT NULL)"
           )

    create constraint(:api_tokens, :api_tokens_agent_not_bootstrap_check,
             check: "agent_id IS NULL OR bootstrap = false"
           )

    create table(:agent_project_access_grants, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :restrict),
        null: false

      add :project_id, :binary_id, null: false
      add :agent_id, :binary_id, null: false
      add :access, :string, null: false, default: "reader"
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:agent_project_access_grants, [:project_id, :agent_id],
             name: :agent_project_access_grants_project_agent_index
           )

    create constraint(:agent_project_access_grants, :agent_project_access_grants_access_check,
             check: "access = 'reader'"
           )

    execute("""
    ALTER TABLE agent_project_access_grants
    ADD CONSTRAINT agent_project_access_grants_project_tenant_fkey
    FOREIGN KEY (project_id, organization_id) REFERENCES projects(id, organization_id)
    ON DELETE RESTRICT
    """)

    execute("""
    ALTER TABLE agent_project_access_grants
    ADD CONSTRAINT agent_project_access_grants_agent_tenant_fkey
    FOREIGN KEY (agent_id, organization_id) REFERENCES agents(id, organization_id)
    ON DELETE RESTRICT
    """)

    execute("""
    UPDATE api_tokens AS token
    SET scopes = array_append(token.scopes, 'agents.manage'), updated_at = NOW()
    FROM organization_memberships AS membership
    WHERE membership.id = token.membership_id
      AND membership.role = 'owner'
      AND membership.deactivated_at IS NULL
      AND token.revoked_at IS NULL
      AND (token.expires_at IS NULL OR token.expires_at > NOW())
      AND token.scopes @> ARRAY[
        'projects.create', 'projects.manage_access', 'memory.write', 'memory.read',
        'search.keyword', 'members.manage', 'teams.manage', 'tokens.manage'
      ]::varchar[]
      AND NOT ('agents.manage' = ANY(token.scopes))
    """)
  end

  def down do
    execute(
      "UPDATE api_tokens SET scopes = array_remove(scopes, 'agents.manage'), updated_at = NOW() WHERE 'agents.manage' = ANY(scopes)"
    )

    drop table(:agent_project_access_grants)

    drop constraint(:api_tokens, :api_tokens_agent_not_bootstrap_check)
    drop constraint(:api_tokens, :api_tokens_exactly_one_principal_check)
    drop index(:api_tokens, [:agent_id])

    alter table(:api_tokens) do
      remove :agent_id
      modify :membership_id, :binary_id, null: false
    end

    drop table(:agents)
  end
end
