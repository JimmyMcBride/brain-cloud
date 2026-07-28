defmodule BrainCloud.Memories.Memory do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "memories" do
    belongs_to :project, BrainCloud.Projects.Project
    has_many :revisions, BrainCloud.Memories.MemoryRevision

    timestamps()
  end

  def changeset(memory, attrs) do
    memory
    |> cast(attrs, [:project_id])
    |> validate_required([:project_id])
    |> foreign_key_constraint(:project_id)
  end
end
