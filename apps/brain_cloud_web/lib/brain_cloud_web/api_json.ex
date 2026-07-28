defmodule BrainCloudWeb.APIJSON do
  @moduledoc false

  def project(project) do
    %{
      id: project.id,
      name: project.name,
      creator_actor_id: project.creator_actor_id,
      inserted_at: timestamp(project.inserted_at),
      updated_at: timestamp(project.updated_at)
    }
  end

  def memory(memory) do
    %{
      id: memory.id,
      project_id: memory.project_id,
      inserted_at: timestamp(memory.inserted_at),
      updated_at: timestamp(memory.updated_at),
      revision: revision(List.first(memory.revisions))
    }
  end

  def search_result(result) do
    %{
      memory_id: result.memory_id,
      revision_id: result.revision_id,
      revision_number: result.revision_number,
      title: result.title,
      content_type: result.content_type,
      content_hash: result.content_hash,
      excerpt: result.excerpt,
      rank: result.rank,
      actor_id: result.actor_id,
      inserted_at: timestamp(result.inserted_at)
    }
  end

  defp revision(revision) do
    %{
      id: revision.id,
      memory_id: revision.memory_id,
      revision_number: revision.revision_number,
      title: revision.title,
      content: revision.content,
      content_type: revision.content_type,
      content_hash: revision.content_hash,
      actor_id: revision.actor_id,
      inserted_at: timestamp(revision.inserted_at)
    }
  end

  defp timestamp(value), do: DateTime.to_iso8601(value)
end
