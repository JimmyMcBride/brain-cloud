defmodule BrainCloud.Repo.Migrations.AddBrowserAuthentication do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :email_verified_at, :utc_datetime_usec
    end

    create unique_index(:organization_memberships, [:id, :user_id],
             name: :organization_memberships_id_user_id_index
           )

    create table(:browser_login_challenges, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :public_id, :string, null: false
      add :token_digest, :binary, null: false
      add :sent_at, :utc_datetime_usec
      add :consumed_at, :utc_datetime_usec
      add :revoked_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:browser_login_challenges, [:public_id])
    create unique_index(:browser_login_challenges, [:token_digest])
    create index(:browser_login_challenges, [:user_id, :sent_at])

    create unique_index(:browser_login_challenges, [:user_id],
             name: :browser_login_challenges_active_user_index,
             where: "consumed_at IS NULL AND revoked_at IS NULL"
           )

    create constraint(:browser_login_challenges, :browser_login_challenges_public_id_length_check,
             check: "char_length(public_id) = 32"
           )

    create constraint(:browser_login_challenges, :browser_login_challenges_digest_length_check,
             check: "octet_length(token_digest) = 32"
           )

    create constraint(:browser_login_challenges, :browser_login_challenges_terminal_state_check,
             check: "consumed_at IS NULL OR revoked_at IS NULL"
           )

    create table(:browser_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :selected_membership_id, :binary_id
      add :public_id, :string, null: false
      add :token_digest, :binary, null: false
      add :authenticated_at, :utc_datetime_usec, null: false
      add :expires_at, :utc_datetime_usec, null: false
      add :revoked_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:browser_sessions, [:public_id])
    create unique_index(:browser_sessions, [:token_digest])

    create unique_index(:browser_sessions, [:id, :user_id],
             name: :browser_sessions_id_user_id_index
           )

    create index(:browser_sessions, [:user_id, :expires_at])
    create index(:browser_sessions, [:selected_membership_id])

    create constraint(:browser_sessions, :browser_sessions_public_id_length_check,
             check: "char_length(public_id) = 32"
           )

    create constraint(:browser_sessions, :browser_sessions_digest_length_check,
             check: "octet_length(token_digest) = 32"
           )

    create constraint(:browser_sessions, :browser_sessions_expiry_check,
             check: "expires_at > authenticated_at"
           )

    execute("""
    ALTER TABLE browser_sessions
    ADD CONSTRAINT browser_sessions_selected_membership_user_fkey
    FOREIGN KEY (selected_membership_id, user_id)
    REFERENCES organization_memberships(id, user_id)
    ON DELETE RESTRICT
    """)

    create table(:user_auth_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :browser_session_id, :binary_id, null: false
      add :action, :string, null: false
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:user_auth_events, [:user_id, :inserted_at])
    create index(:user_auth_events, [:browser_session_id, :inserted_at])

    create constraint(:user_auth_events, :user_auth_events_action_check,
             check:
               "action IN ('email.verify', 'session.create', 'session.reissue', 'organization.select', 'session.logout')"
           )

    execute("""
    ALTER TABLE user_auth_events
    ADD CONSTRAINT user_auth_events_session_user_fkey
    FOREIGN KEY (browser_session_id, user_id)
    REFERENCES browser_sessions(id, user_id)
    ON DELETE RESTRICT
    """)
  end

  def down do
    drop table(:user_auth_events)

    execute(
      "ALTER TABLE browser_sessions DROP CONSTRAINT browser_sessions_selected_membership_user_fkey"
    )

    drop table(:browser_sessions)
    drop table(:browser_login_challenges)

    drop index(:organization_memberships, [:id, :user_id],
           name: :organization_memberships_id_user_id_index
         )

    alter table(:users) do
      remove :email_verified_at
    end
  end
end
