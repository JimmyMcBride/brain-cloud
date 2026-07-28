defmodule BrainCloud.Repo.Migrations.CreateIdentityAndTenantFoundation do
  use Ecto.Migration

  @phase_one_organization_id "00000000-0000-0000-0000-0000000000f1"

  def up do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :display_name, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:users, [:email])

    create table(:organizations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:organizations, [:slug])

    create table(:organization_memberships, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :user_id, references(:users, type: :binary_id, on_delete: :restrict), null: false

      add :organization_id,
          references(:organizations, type: :binary_id, on_delete: :restrict),
          null: false

      add :role, :string, null: false
      add :deactivated_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:organization_memberships, [:user_id, :organization_id])
    create index(:organization_memberships, [:organization_id])

    create constraint(:organization_memberships, :organization_memberships_role_check,
             check: "role IN ('owner', 'member')"
           )

    create table(:api_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :membership_id,
          references(:organization_memberships, type: :binary_id, on_delete: :restrict),
          null: false

      add :public_id, :string, null: false
      add :token_digest, :binary, null: false
      add :name, :string, null: false
      add :scopes, {:array, :string}, null: false, default: []
      add :expires_at, :utc_datetime_usec
      add :revoked_at, :utc_datetime_usec
      add :bootstrap, :boolean, null: false, default: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:api_tokens, [:public_id])

    create unique_index(:api_tokens, [:membership_id],
             name: :api_tokens_active_bootstrap_index,
             where: "bootstrap = true AND revoked_at IS NULL"
           )

    create index(:api_tokens, [:membership_id])

    create table(:audit_events, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id,
          references(:organizations, type: :binary_id, on_delete: :restrict),
          null: false

      add :actor_user_id, references(:users, type: :binary_id, on_delete: :restrict), null: false

      add :api_token_id, references(:api_tokens, type: :binary_id, on_delete: :restrict)
      add :action, :string, null: false
      add :resource_type, :string
      add :resource_id, :binary_id
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:audit_events, [:organization_id, :inserted_at])
    create index(:audit_events, [:actor_user_id, :inserted_at])

    execute("""
    INSERT INTO organizations (id, name, slug, inserted_at, updated_at)
    VALUES (
      '#{@phase_one_organization_id}',
      'Phase 1 import',
      'phase-1-import',
      NOW(),
      NOW()
    )
    ON CONFLICT (id) DO NOTHING
    """)

    execute("""
    INSERT INTO users (id, email, display_name, inserted_at, updated_at)
    SELECT
      actor_id,
      'phase1-' || replace(actor_id::text, '-', '') || '@invalid.brain-cloud.local',
      'Phase 1 actor ' || actor_id::text,
      NOW(),
      NOW()
    FROM (
      SELECT creator_actor_id AS actor_id FROM projects
      UNION
      SELECT actor_id FROM memory_revisions
    ) actors
    ON CONFLICT (id) DO NOTHING
    """)

    execute("""
    INSERT INTO organization_memberships (
      id,
      user_id,
      organization_id,
      role,
      inserted_at,
      updated_at
    )
    SELECT
      md5('phase1-membership:' || id::text)::uuid,
      id,
      '#{@phase_one_organization_id}',
      'member',
      NOW(),
      NOW()
    FROM users
    WHERE email LIKE 'phase1-%@invalid.brain-cloud.local'
    ON CONFLICT (user_id, organization_id) DO NOTHING
    """)

    alter table(:projects) do
      add :organization_id,
          references(:organizations, type: :binary_id, on_delete: :restrict)
    end

    execute("""
    UPDATE projects
    SET organization_id = '#{@phase_one_organization_id}'
    WHERE organization_id IS NULL
    """)

    execute("ALTER TABLE projects ALTER COLUMN organization_id SET NOT NULL")
    create index(:projects, [:organization_id])

    execute("""
    ALTER TABLE projects
    ADD CONSTRAINT projects_creator_actor_id_fkey
    FOREIGN KEY (creator_actor_id) REFERENCES users(id) ON DELETE RESTRICT
    """)

    execute("""
    ALTER TABLE memory_revisions
    ADD CONSTRAINT memory_revisions_actor_id_fkey
    FOREIGN KEY (actor_id) REFERENCES users(id) ON DELETE RESTRICT
    """)
  end

  def down do
    execute(
      "ALTER TABLE memory_revisions DROP CONSTRAINT IF EXISTS memory_revisions_actor_id_fkey"
    )

    execute("ALTER TABLE projects DROP CONSTRAINT IF EXISTS projects_creator_actor_id_fkey")

    alter table(:projects) do
      remove :organization_id
    end

    drop table(:audit_events)
    drop table(:api_tokens)
    drop table(:organization_memberships)
    drop table(:organizations)
    drop table(:users)
  end
end
