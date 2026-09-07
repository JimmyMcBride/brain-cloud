defmodule BrainCloud.Repo.Migrations.AddInvitationDelivery do
  use Ecto.Migration

  def change do
    create unique_index(:organization_invitations, [:id, :organization_id])

    alter table(:organization_invitations) do
      add :delivery_state, :text, null: false, default: "manual"
      add :delivery_generation, :uuid
    end

    create constraint(:organization_invitations, :invitation_delivery_state_check,
             check:
               "(delivery_state = 'manual' AND delivery_generation IS NULL) OR (delivery_state IN ('sending', 'sent', 'failed') AND delivery_generation IS NOT NULL)"
           )

    create table(:invitation_delivery_attempts, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :organization_id, references(:organizations, type: :uuid), null: false
      add :invitation_id, references(:organization_invitations, type: :uuid), null: false
      add :requested_by_user_id, references(:users, type: :uuid), null: false
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:invitation_delivery_attempts, [:organization_id, :inserted_at])
    create index(:invitation_delivery_attempts, [:invitation_id, :inserted_at])
    create unique_index(:invitation_delivery_attempts, [:id, :invitation_id, :organization_id])

    execute "ALTER TABLE invitation_delivery_attempts ADD CONSTRAINT invitation_delivery_attempts_tenant_fkey FOREIGN KEY (invitation_id, organization_id) REFERENCES organization_invitations(id, organization_id)",
            "ALTER TABLE invitation_delivery_attempts DROP CONSTRAINT invitation_delivery_attempts_tenant_fkey"

    execute "ALTER TABLE organization_invitations ADD CONSTRAINT invitation_delivery_generation_fkey FOREIGN KEY (delivery_generation, id, organization_id) REFERENCES invitation_delivery_attempts(id, invitation_id, organization_id)",
            "ALTER TABLE organization_invitations DROP CONSTRAINT invitation_delivery_generation_fkey"
  end
end
