defmodule BrainCloud.Repo.Migrations.CreateProjectAccessGrants do
  use Ecto.Migration

  def up do
    create unique_index(:projects, [:id, :organization_id],
             name: :projects_id_organization_id_index
           )

    create unique_index(:organization_memberships, [:id, :organization_id],
             name: :organization_memberships_id_organization_id_index
           )

    create table(:project_access_grants, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id,
          references(:organizations, type: :binary_id, on_delete: :restrict),
          null: false

      add :project_id, :binary_id, null: false
      add :organization_membership_id, :binary_id, null: false
      add :access, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:project_access_grants, [:project_id, :organization_membership_id],
             name: :project_access_grants_project_membership_index
           )

    create index(:project_access_grants, [:organization_id, :project_id])

    create index(:project_access_grants, [:organization_id, :organization_membership_id],
             name: :project_access_grants_organization_membership_index
           )

    create constraint(:project_access_grants, :project_access_grants_access_check,
             check: "access IN ('reader', 'editor')"
           )

    execute("""
    ALTER TABLE project_access_grants
    ADD CONSTRAINT project_access_grants_project_tenant_fkey
    FOREIGN KEY (project_id, organization_id)
    REFERENCES projects(id, organization_id)
    ON DELETE RESTRICT
    """)

    execute("""
    ALTER TABLE project_access_grants
    ADD CONSTRAINT project_access_grants_membership_tenant_fkey
    FOREIGN KEY (organization_membership_id, organization_id)
    REFERENCES organization_memberships(id, organization_id)
    ON DELETE RESTRICT
    """)

    execute("""
    UPDATE api_tokens AS token
    SET
      scopes = array_append(token.scopes, 'projects.manage_access'),
      updated_at = NOW()
    FROM organization_memberships AS membership
    WHERE
      membership.id = token.membership_id
      AND membership.role = 'owner'
      AND membership.deactivated_at IS NULL
      AND token.revoked_at IS NULL
      AND (token.expires_at IS NULL OR token.expires_at > NOW())
      AND 'members.manage' = ANY(token.scopes)
      AND NOT ('projects.manage_access' = ANY(token.scopes))
    """)

    execute("""
    INSERT INTO project_access_grants (
      id,
      organization_id,
      project_id,
      organization_membership_id,
      access,
      inserted_at,
      updated_at
    )
    SELECT
      md5('project-access:' || project.id::text || ':' || membership.id::text)::uuid,
      project.organization_id,
      project.id,
      membership.id,
      'editor',
      NOW(),
      NOW()
    FROM projects AS project
    JOIN organization_memberships AS membership
      ON membership.organization_id = project.organization_id
    WHERE membership.role = 'member'
    ON CONFLICT (project_id, organization_membership_id) DO NOTHING
    """)
  end

  def down do
    execute("""
    UPDATE api_tokens
    SET
      scopes = array_remove(scopes, 'projects.manage_access'),
      updated_at = NOW()
    WHERE 'projects.manage_access' = ANY(scopes)
    """)

    drop table(:project_access_grants)

    drop index(:organization_memberships, [:id, :organization_id],
           name: :organization_memberships_id_organization_id_index
         )

    drop index(:projects, [:id, :organization_id], name: :projects_id_organization_id_index)
  end
end
