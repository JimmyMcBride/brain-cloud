defmodule BrainCloud.Memories.MemoryRevision do
  use Ecto.Schema

  import Ecto.Changeset

  @maximum_content_bytes 1_048_576
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "memory_revisions" do
    field :revision_number, :integer
    field :title, :string
    field :content, :string
    field :content_type, :string
    field :content_hash, :string
    field :actor_id, :binary_id
    field :search_vector, :string, load_in_query: false

    belongs_to :memory, BrainCloud.Memories.Memory

    timestamps()
  end

  def changeset(revision, attrs) do
    revision
    |> cast(
      attrs,
      [
        :memory_id,
        :revision_number,
        :title,
        :content,
        :content_type,
        :actor_id
      ],
      empty_values: [nil]
    )
    |> update_change(:title, &String.trim/1)
    |> validate_required([
      :memory_id,
      :revision_number,
      :title,
      :content_type,
      :actor_id
    ])
    |> validate_number(:revision_number, equal_to: 1)
    |> validate_length(:title, min: 1, max: 200)
    |> validate_inclusion(:content_type, ["text/markdown"])
    |> validate_content()
    |> put_content_hash()
    |> validate_uuid(:actor_id)
    |> foreign_key_constraint(:memory_id)
    |> unique_constraint([:memory_id, :revision_number], error_key: :revision_number)
  end

  defp validate_content(changeset) do
    case get_field(changeset, :content) do
      content when is_binary(content) ->
        case byte_size(content) do
          size when size in 1..@maximum_content_bytes -> changeset
          _size -> add_error(changeset, :content, "must be between 1 byte and 1 MiB")
        end

      _other ->
        add_error(changeset, :content, "can't be blank")
    end
  end

  defp put_content_hash(changeset) do
    if content = get_change(changeset, :content) do
      put_change(
        changeset,
        :content_hash,
        content
        |> then(&:crypto.hash(:sha256, &1))
        |> Base.encode16(case: :lower)
      )
    else
      changeset
    end
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
