defmodule BrainCloud.Memories do
  @moduledoc """
  Stores immutable memory revisions and provides project-scoped keyword search.
  """

  import Ecto.Query

  alias BrainCloud.Memories.Memory
  alias BrainCloud.Memories.MemoryRevision
  alias BrainCloud.Accounts
  alias BrainCloud.Accounts.AuthContext
  alias BrainCloud.Projects
  alias BrainCloud.Repo
  alias Ecto.Multi

  @maximum_query_length 256

  def create_memory(project_id, attrs, %AuthContext{} = auth) do
    case Projects.get_project(project_id, auth.organization_id) do
      nil ->
        {:error, :project_not_found}

      project ->
        attrs = Map.new(attrs)

        Multi.new()
        |> Multi.insert(:memory, Memory.changeset(%Memory{}, %{project_id: project.id}))
        |> Multi.insert(:revision, fn %{memory: memory} ->
          %{
            memory_id: memory.id,
            revision_number: 1,
            title: attribute(attrs, :title),
            content: attribute(attrs, :content),
            content_type: attribute(attrs, :content_type),
            actor_id: auth.user_id
          }
          |> then(&MemoryRevision.changeset(%MemoryRevision{}, &1))
        end)
        |> Multi.insert(:audit_event, fn %{memory: memory} ->
          Accounts.audit_changeset(auth, "memory.create", "memory", memory.id)
        end)
        |> Repo.transaction()
        |> case do
          {:ok, %{memory: memory, revision: revision}} ->
            {:ok, %{memory | revisions: [revision]}}

          {:error, :revision, changeset, _changes} ->
            {:error, changeset}

          {:error, :memory, changeset, _changes} ->
            {:error, changeset}

          {:error, :audit_event, changeset, _changes} ->
            {:error, changeset}
        end
    end
  end

  def get_memory(project_id, memory_id, organization_id) do
    with {:ok, project_id} <- Ecto.UUID.cast(project_id),
         {:ok, memory_id} <- Ecto.UUID.cast(memory_id),
         {:ok, organization_id} <- Ecto.UUID.cast(organization_id) do
      revisions = from revision in MemoryRevision, order_by: revision.revision_number

      Repo.one(
        from memory in Memory,
          join: project in assoc(memory, :project),
          where: memory.id == ^memory_id and memory.project_id == ^project_id,
          where: project.organization_id == ^organization_id,
          preload: [revisions: ^revisions]
      )
    else
      :error -> nil
    end
  end

  def search(project_id, query, organization_id) do
    with project when not is_nil(project) <- Projects.get_project(project_id, organization_id),
         {:ok, query} <- validate_query(query) do
      results =
        Repo.all(
          from revision in MemoryRevision,
            join: memory in Memory,
            on: memory.id == revision.memory_id,
            join: scoped_project in assoc(memory, :project),
            where: memory.project_id == ^project.id,
            where: scoped_project.organization_id == ^organization_id,
            where:
              fragment(
                "? @@ plainto_tsquery('simple', ?)",
                revision.search_vector,
                ^query
              ),
            order_by: [
              desc:
                fragment(
                  "ts_rank(?, plainto_tsquery('simple', ?))",
                  revision.search_vector,
                  ^query
                ),
              asc: revision.id
            ],
            select: %{
              memory_id: memory.id,
              revision_id: revision.id,
              revision_number: revision.revision_number,
              title: revision.title,
              content: revision.content,
              content_type: revision.content_type,
              content_hash: revision.content_hash,
              actor_id: revision.actor_id,
              inserted_at: revision.inserted_at,
              rank:
                type(
                  fragment(
                    "ts_rank(?, plainto_tsquery('simple', ?))",
                    revision.search_vector,
                    ^query
                  ),
                  :float
                )
            }
        )
        |> Enum.map(&Map.put(&1, :excerpt, plain_text_excerpt(&1.content)))
        |> Enum.map(&Map.delete(&1, :content))

      {:ok, results}
    else
      nil -> {:error, :project_not_found}
      {:error, details} -> {:error, {:validation_failed, details}}
    end
  end

  defp validate_query(query) when is_binary(query) do
    trimmed = String.trim(query)

    if String.length(trimmed) in 1..@maximum_query_length do
      {:ok, trimmed}
    else
      {:error, %{q: ["must be between 1 and 256 characters"]}}
    end
  end

  defp validate_query(_query) do
    {:error, %{q: ["must be between 1 and 256 characters"]}}
  end

  defp attribute(attrs, key) do
    Map.get(attrs, key, Map.get(attrs, Atom.to_string(key)))
  end

  defp plain_text_excerpt(content) do
    content
    |> String.replace(~r/```.*?```/su, " ")
    |> String.replace(~r/[#>*_`\[\]()!-]+/u, " ")
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
    |> String.slice(0, 240)
  end
end
