defmodule BrainCloudWeb.APIJSON do
  @moduledoc false

  def project(project) do
    %{
      id: project.id,
      organization_id: project.organization_id,
      name: project.name,
      creator_actor_id: project.creator_actor_id,
      inserted_at: timestamp(project.inserted_at),
      updated_at: timestamp(project.updated_at)
    }
  end

  def project_access_grant(grant) do
    %{
      id: grant.id,
      project_id: grant.project_id,
      membership_id: grant.organization_membership_id,
      access: grant.access,
      inserted_at: timestamp(grant.inserted_at),
      updated_at: timestamp(grant.updated_at)
    }
  end

  def team(team) do
    %{
      id: team.id,
      name: team.name,
      active: is_nil(team.deactivated_at),
      deactivated_at: optional_timestamp(team.deactivated_at),
      inserted_at: timestamp(team.inserted_at),
      updated_at: timestamp(team.updated_at)
    }
  end

  def agent(agent) do
    %{
      id: agent.id,
      name: agent.name,
      active: is_nil(agent.deactivated_at),
      deactivated_at: optional_timestamp(agent.deactivated_at),
      inserted_at: timestamp(agent.inserted_at),
      updated_at: timestamp(agent.updated_at)
    }
  end

  def team_membership(link) do
    %{
      id: link.id,
      team_id: link.team_id,
      membership_id: link.organization_membership_id,
      inserted_at: timestamp(link.inserted_at)
    }
  end

  def team_project_access_grant(grant) do
    %{
      id: grant.id,
      project_id: grant.project_id,
      team_id: grant.team_id,
      access: grant.access,
      inserted_at: timestamp(grant.inserted_at),
      updated_at: timestamp(grant.updated_at)
    }
  end

  def agent_project_access_grant(grant) do
    %{
      id: grant.id,
      project_id: grant.project_id,
      agent_id: grant.agent_id,
      access: grant.access,
      inserted_at: timestamp(grant.inserted_at),
      updated_at: timestamp(grant.updated_at)
    }
  end

  def created_token(token, raw_token) do
    token
    |> token()
    |> Map.put(:token, raw_token)
  end

  def token(token) do
    %{
      id: token.id,
      name: token.name,
      scopes: token.scopes,
      expires_at: optional_timestamp(token.expires_at),
      revoked_at: optional_timestamp(token.revoked_at),
      bootstrap: token.bootstrap,
      inserted_at: timestamp(token.inserted_at)
    }
  end

  def membership(membership) do
    %{
      id: membership.id,
      user_id: membership.user_id,
      email: membership.user.email,
      display_name: membership.user.display_name,
      role: membership.role,
      active: is_nil(membership.deactivated_at),
      deactivated_at: optional_timestamp(membership.deactivated_at),
      inserted_at: timestamp(membership.inserted_at),
      updated_at: timestamp(membership.updated_at)
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
  defp optional_timestamp(nil), do: nil
  defp optional_timestamp(value), do: timestamp(value)
end
