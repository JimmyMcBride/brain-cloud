defmodule BrainCloud.Projects.Project do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "projects" do
    field :name, :string
    field :creator_actor_id, :binary_id

    belongs_to :organization, BrainCloud.Accounts.Organization
    has_many :memories, BrainCloud.Memories.Memory

    timestamps()
  end

  def changeset(project, attrs) do
    project
    |> cast(attrs, [:name, :creator_actor_id, :organization_id])
    |> update_change(:name, &String.trim/1)
    |> validate_required([:name, :creator_actor_id, :organization_id])
    |> validate_length(:name, min: 1, max: 120)
    |> validate_uuid(:creator_actor_id)
    |> foreign_key_constraint(:creator_actor_id)
    |> foreign_key_constraint(:organization_id)
  end

  defp validate_uuid(changeset, field) do
    validate_change(changeset, field, fn ^field, value ->
      case Ecto.UUID.cast(value) do
        {:ok, _uuid} -> []
        :error -> [{field, "is invalid"}]
      end
    end)
  end
end
