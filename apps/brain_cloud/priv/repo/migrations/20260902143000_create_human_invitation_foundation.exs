defmodule BrainCloud.Repo.Migrations.CreateHumanInvitationFoundation do
  use Ecto.Migration

  def up do
    create table(:organization_invitations, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id,
          references(:organizations, type: :binary_id, on_delete: :restrict),
          null: false

      add :created_by_membership_id, :binary_id, null: false
      add :accepted_membership_id, :binary_id
      add :email, :string, null: false
      add :display_name, :string, null: false
      add :role, :string, null: false, default: "member"
      add :scopes, {:array, :string}, null: false, default: []
      add :public_id, :string, null: false
      add :secret_digest, :binary, null: false
      add :expires_at, :utc_datetime_usec, null: false
      add :accepted_at, :utc_datetime_usec
      add :revoked_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:organization_invitations, [:public_id])

    create unique_index(:organization_invitations, [:organization_id, :email],
             name: :organization_invitations_unresolved_email_index,
             where: "accepted_at IS NULL AND revoked_at IS NULL"
           )

    create index(:organization_invitations, [:organization_id, :inserted_at])
    create index(:organization_invitations, [:accepted_membership_id])

    create constraint(:organization_invitations, :organization_invitations_role_check,
             check: "role = 'member'"
           )

    create constraint(
             :organization_invitations,
             :organization_invitations_normalized_email_check,
             check: "email = lower(btrim(email))"
           )

    create constraint(
             :organization_invitations,
             :organization_invitations_public_id_length_check,
             check: "char_length(public_id) = 32"
           )

    create constraint(
             :organization_invitations,
             :organization_invitations_digest_length_check,
             check: "octet_length(secret_digest) = 32"
           )

    create constraint(
             :organization_invitations,
             :organization_invitations_terminal_state_check,
             check: "accepted_at IS NULL OR revoked_at IS NULL"
           )

    create constraint(
             :organization_invitations,
             :organization_invitations_accepted_membership_check,
             check: "(accepted_at IS NULL) = (accepted_membership_id IS NULL)"
           )

    execute("""
    ALTER TABLE organization_invitations
    ADD CONSTRAINT organization_invitations_creator_tenant_fkey
    FOREIGN KEY (created_by_membership_id, organization_id)
    REFERENCES organization_memberships(id, organization_id)
    ON DELETE RESTRICT
    """)

    execute("""
    ALTER TABLE organization_invitations
    ADD CONSTRAINT organization_invitations_accepted_membership_tenant_fkey
    FOREIGN KEY (accepted_membership_id, organization_id)
    REFERENCES organization_memberships(id, organization_id)
    ON DELETE RESTRICT
    """)
  end

  def down do
    drop table(:organization_invitations)
  end
end
