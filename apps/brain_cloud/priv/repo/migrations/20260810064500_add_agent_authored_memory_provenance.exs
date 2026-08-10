defmodule BrainCloud.Repo.Migrations.AddAgentAuthoredMemoryProvenance do
  use Ecto.Migration

  def up do
    drop constraint(:agent_project_access_grants, :agent_project_access_grants_access_check)

    create constraint(:agent_project_access_grants, :agent_project_access_grants_access_check,
             check: "access IN ('reader', 'editor')"
           )

    rename table(:memory_revisions), :actor_id, to: :actor_user_id

    execute("""
    ALTER TABLE memory_revisions
    RENAME CONSTRAINT memory_revisions_actor_id_fkey
    TO memory_revisions_actor_user_id_fkey
    """)

    alter table(:memory_revisions) do
      modify :actor_user_id, :binary_id, null: true
      add :actor_agent_id, references(:agents, type: :binary_id, on_delete: :restrict)
    end

    create index(:memory_revisions, [:actor_agent_id, :inserted_at])

    create constraint(:memory_revisions, :memory_revisions_exactly_one_actor_check,
             check: "(actor_user_id IS NOT NULL) <> (actor_agent_id IS NOT NULL)"
           )

    alter table(:audit_events) do
      modify :actor_user_id, :binary_id, null: true
      add :actor_agent_id, :binary_id
    end

    create index(:audit_events, [:actor_agent_id, :inserted_at])

    create constraint(:audit_events, :audit_events_exactly_one_actor_check,
             check: "(actor_user_id IS NOT NULL) <> (actor_agent_id IS NOT NULL)"
           )

    execute("""
    ALTER TABLE audit_events
    ADD CONSTRAINT audit_events_actor_agent_tenant_fkey
    FOREIGN KEY (actor_agent_id, organization_id)
    REFERENCES agents(id, organization_id)
    ON DELETE RESTRICT
    """)

    execute("""
    CREATE FUNCTION enforce_memory_revision_agent_tenant()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      IF NEW.actor_agent_id IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM agents AS agent
        JOIN memories AS memory ON memory.id = NEW.memory_id
        JOIN projects AS project ON project.id = memory.project_id
        WHERE agent.id = NEW.actor_agent_id
          AND agent.organization_id = project.organization_id
      ) THEN
        RAISE EXCEPTION 'agent memory revision actor must belong to the project organization'
          USING ERRCODE = '23514',
                CONSTRAINT = 'memory_revisions_actor_agent_tenant_check';
      END IF;

      RETURN NEW;
    END;
    $$
    """)

    execute("""
    CREATE CONSTRAINT TRIGGER memory_revisions_actor_agent_tenant_check
    AFTER INSERT OR UPDATE OF memory_id, actor_agent_id
    ON memory_revisions
    DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE FUNCTION enforce_memory_revision_agent_tenant()
    """)
  end

  def down do
    execute("""
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM memory_revisions WHERE actor_agent_id IS NOT NULL)
         OR EXISTS (SELECT 1 FROM audit_events WHERE actor_agent_id IS NOT NULL) THEN
        RAISE EXCEPTION 'cannot remove agent provenance while agent-authored rows exist';
      END IF;
    END;
    $$
    """)

    execute("DROP TRIGGER memory_revisions_actor_agent_tenant_check ON memory_revisions")

    execute("DROP FUNCTION enforce_memory_revision_agent_tenant()")

    execute("ALTER TABLE audit_events DROP CONSTRAINT audit_events_actor_agent_tenant_fkey")

    drop constraint(:audit_events, :audit_events_exactly_one_actor_check)
    drop index(:audit_events, [:actor_agent_id, :inserted_at])

    alter table(:audit_events) do
      remove :actor_agent_id
      modify :actor_user_id, :binary_id, null: false
    end

    drop constraint(:memory_revisions, :memory_revisions_exactly_one_actor_check)
    drop index(:memory_revisions, [:actor_agent_id, :inserted_at])

    alter table(:memory_revisions) do
      remove :actor_agent_id
      modify :actor_user_id, :binary_id, null: false
    end

    execute("""
    ALTER TABLE memory_revisions
    RENAME CONSTRAINT memory_revisions_actor_user_id_fkey
    TO memory_revisions_actor_id_fkey
    """)

    rename table(:memory_revisions), :actor_user_id, to: :actor_id

    drop constraint(:agent_project_access_grants, :agent_project_access_grants_access_check)

    create constraint(:agent_project_access_grants, :agent_project_access_grants_access_check,
             check: "access = 'reader'"
           )
  end
end
