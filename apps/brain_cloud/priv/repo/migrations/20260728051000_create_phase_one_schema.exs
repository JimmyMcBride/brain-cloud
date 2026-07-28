defmodule BrainCloud.Repo.Migrations.CreatePhaseOneSchema do
  use Ecto.Migration

  def change do
    create table(:projects, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :creator_actor_id, :binary_id, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create table(:memories, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:memories, [:project_id])

    create table(:memory_revisions, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :memory_id, references(:memories, type: :binary_id, on_delete: :delete_all), null: false

      add :revision_number, :integer, null: false
      add :title, :string, null: false
      add :content, :text, null: false
      add :content_type, :string, null: false
      add :content_hash, :string, null: false
      add :actor_id, :binary_id, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:memory_revisions, [:memory_id, :revision_number])

    execute(
      """
      ALTER TABLE memory_revisions
      ADD COLUMN search_vector tsvector
      GENERATED ALWAYS AS (
        to_tsvector(
          'simple',
          coalesce(title, '') || ' ' || coalesce(content, '')
        )
      ) STORED
      """,
      "ALTER TABLE memory_revisions DROP COLUMN search_vector"
    )

    create index(:memory_revisions, [:search_vector], using: :gin)
  end
end
