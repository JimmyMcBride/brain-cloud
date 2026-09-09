defmodule BrainCloud.Repo.Migrations.AddProjectDiscoveryIndex do
  use Ecto.Migration

  def change do
    create index(:projects, [:organization_id, :inserted_at, :id],
             name: :projects_organization_pagination_index
           )
  end
end
