defmodule BrainCloud.Repo.Migrations.CreateTeamAccessFoundation do
  use Ecto.Migration

  def up do
    create table(:teams, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :restrict),
        null: false

      add :name, :string, null: false
      add :deactivated_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:teams, [:id, :organization_id], name: :teams_id_organization_id_index)

    execute(
      "CREATE UNIQUE INDEX teams_organization_lower_name_index ON teams (organization_id, lower(name))"
    )

    create table(:team_memberships, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :restrict),
        null: false

      add :team_id, :binary_id, null: false
      add :organization_membership_id, :binary_id, null: false
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:team_memberships, [:team_id, :organization_membership_id],
             name: :team_memberships_team_membership_index
           )

    execute("""
    ALTER TABLE team_memberships
    ADD CONSTRAINT team_memberships_team_tenant_fkey
    FOREIGN KEY (team_id, organization_id) REFERENCES teams(id, organization_id)
    ON DELETE RESTRICT
    """)

    execute("""
    ALTER TABLE team_memberships
    ADD CONSTRAINT team_memberships_membership_tenant_fkey
    FOREIGN KEY (organization_membership_id, organization_id)
    REFERENCES organization_memberships(id, organization_id)
    ON DELETE RESTRICT
    """)

    create table(:team_project_access_grants, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :restrict),
        null: false

      add :project_id, :binary_id, null: false
      add :team_id, :binary_id, null: false
      add :access, :string, null: false
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:team_project_access_grants, [:project_id, :team_id],
             name: :team_project_access_grants_project_team_index
           )

    create constraint(:team_project_access_grants, :team_project_access_grants_access_check,
             check: "access IN ('reader', 'editor')"
           )

    execute("""
    ALTER TABLE team_project_access_grants
    ADD CONSTRAINT team_project_access_grants_project_tenant_fkey
    FOREIGN KEY (project_id, organization_id) REFERENCES projects(id, organization_id)
    ON DELETE RESTRICT
    """)

    execute("""
    ALTER TABLE team_project_access_grants
    ADD CONSTRAINT team_project_access_grants_team_tenant_fkey
    FOREIGN KEY (team_id, organization_id) REFERENCES teams(id, organization_id)
    ON DELETE RESTRICT
    """)

    execute("""
    UPDATE api_tokens AS token
    SET scopes = array_append(token.scopes, 'teams.manage'), updated_at = NOW()
    FROM organization_memberships AS membership
    WHERE membership.id = token.membership_id
      AND membership.role = 'owner'
      AND membership.deactivated_at IS NULL
      AND token.revoked_at IS NULL
      AND (token.expires_at IS NULL OR token.expires_at > NOW())
      AND token.scopes @> ARRAY[
        'projects.create', 'projects.manage_access', 'memory.write', 'memory.read',
        'search.keyword', 'members.manage', 'tokens.manage'
      ]::varchar[]
      AND NOT ('teams.manage' = ANY(token.scopes))
    """)
  end

  def down do
    execute(
      "UPDATE api_tokens SET scopes = array_remove(scopes, 'teams.manage'), updated_at = NOW() WHERE 'teams.manage' = ANY(scopes)"
    )

    drop table(:team_project_access_grants)
    drop table(:team_memberships)
    drop table(:teams)
  end
end
