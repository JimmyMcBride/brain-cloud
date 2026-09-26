defmodule BrainCloud.Repo.Migrations.AddMemoryDiscoveryIndex do
  use Ecto.Migration

  def change do
    drop index(:memories, [:project_id])
    create index(:memories, [:project_id, :inserted_at, :id])
  end
end
