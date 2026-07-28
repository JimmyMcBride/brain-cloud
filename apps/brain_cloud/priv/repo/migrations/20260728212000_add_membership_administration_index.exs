defmodule BrainCloud.Repo.Migrations.AddMembershipAdministrationIndex do
  use Ecto.Migration

  def change do
    create index(:organization_memberships, [:organization_id, :role, :deactivated_at],
             name: :organization_memberships_owner_state_index
           )
  end
end
