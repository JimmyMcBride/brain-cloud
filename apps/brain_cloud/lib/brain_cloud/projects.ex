defmodule BrainCloud.Projects do
  @moduledoc """
  Creates and retrieves cloud-native projects.
  """

  import Ecto.Query

  alias BrainCloud.Accounts
  alias BrainCloud.Accounts.ApiToken
  alias BrainCloud.Accounts.AuthContext
  alias BrainCloud.Accounts.OrganizationMembership
  alias BrainCloud.Agents.Agent
  alias BrainCloud.Projects.AgentProjectAccessGrant
  alias BrainCloud.Projects.Project
  alias BrainCloud.Projects.ProjectAccessGrant
  alias BrainCloud.Projects.TeamProjectAccessGrant
  alias BrainCloud.Repo
  alias BrainCloud.Teams.Team
  alias BrainCloud.Teams.TeamMembership
  alias Ecto.Multi

  @reader_access ~w(reader editor)
  @editor_access ~w(editor)

  def create_project(attrs, %AuthContext{} = auth) do
    attrs = Map.new(attrs)

    Multi.new()
    |> Multi.insert(
      :project,
      Project.changeset(%Project{}, %{
        name: attribute(attrs, :name),
        creator_actor_id: auth.user_id,
        organization_id: auth.organization_id
      })
    )
    |> Multi.run(:creator_access_grant, fn repo, %{project: project} ->
      if auth.role == "member" do
        %ProjectAccessGrant{}
        |> ProjectAccessGrant.changeset(%{
          organization_id: auth.organization_id,
          project_id: project.id,
          organization_membership_id: auth.membership_id,
          access: "editor"
        })
        |> repo.insert()
      else
        {:ok, nil}
      end
    end)
    |> Multi.insert(:audit_event, fn %{project: project} ->
      Accounts.audit_changeset(auth, "project.create", "project", project.id)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{project: project}} -> {:ok, project}
      {:error, :project, changeset, _changes} -> {:error, changeset}
      {:error, :creator_access_grant, changeset, _changes} -> {:error, changeset}
      {:error, :audit_event, changeset, _changes} -> {:error, changeset}
    end
  end

  def get_project(id, organization_id) do
    with {:ok, id} <- Ecto.UUID.cast(id),
         {:ok, organization_id} <- Ecto.UUID.cast(organization_id) do
      Repo.one(
        from project in Project,
          where: project.id == ^id and project.organization_id == ^organization_id
      )
    else
      :error -> nil
    end
  end

  def authorize_project(id, %AuthContext{} = auth, required_access)
      when required_access in [:reader, :editor] do
    with {:ok, id} <- Ecto.UUID.cast(id),
         %Project{} = project <- authorized_project(id, auth, required_access) do
      {:ok, project}
    else
      _missing -> {:error, :project_not_found}
    end
  end

  def authorize_memory_write(id, %AuthContext{principal_type: :human} = auth),
    do: authorize_project(id, auth, :editor)

  def authorize_memory_write(id, %AuthContext{principal_type: :agent} = auth) do
    if Accounts.authorized?(auth, "memory.write") do
      authorize_agent_memory_write(id, auth)
    else
      {:error, :forbidden}
    end
  end

  def list_project_access_grants(project_id, %AuthContext{} = auth) do
    with :ok <- authorize_access_management(auth),
         {:ok, project_id} <- Ecto.UUID.cast(project_id),
         %Project{} <- tenant_project(project_id, auth.organization_id) do
      grants =
        Repo.all(
          from grant in ProjectAccessGrant,
            where:
              grant.project_id == ^project_id and
                grant.organization_id == ^auth.organization_id,
            order_by: [asc: grant.inserted_at, asc: grant.id]
        )

      {:ok, grants}
    else
      :error -> {:error, :project_not_found}
      nil -> {:error, :project_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def put_project_access_grant(
        project_id,
        membership_id,
        access,
        %AuthContext{} = auth
      ) do
    with :ok <- authorize_access_management(auth),
         {:ok, project_id} <- Ecto.UUID.cast(project_id),
         {:ok, membership_id} <- Ecto.UUID.cast(membership_id) do
      Repo.transaction(fn ->
        with %Project{} <- tenant_project(project_id, auth.organization_id),
             %OrganizationMembership{} = membership <-
               tenant_membership_for_update(membership_id, auth.organization_id),
             :ok <- ensure_membership_active(membership) do
          put_grant(project_id, membership_id, access, auth)
        else
          nil -> Repo.rollback(missing_resource(project_id, membership_id, auth))
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
      |> unwrap_transaction()
    else
      :error -> {:error, malformed_resource(project_id, membership_id)}
      {:error, reason} -> {:error, reason}
    end
  end

  def delete_project_access_grant(
        project_id,
        membership_id,
        %AuthContext{} = auth
      ) do
    with :ok <- authorize_access_management(auth),
         {:ok, project_id} <- Ecto.UUID.cast(project_id),
         {:ok, membership_id} <- Ecto.UUID.cast(membership_id) do
      Repo.transaction(fn ->
        with %Project{} <- tenant_project(project_id, auth.organization_id),
             %OrganizationMembership{} <-
               tenant_membership_for_update(membership_id, auth.organization_id) do
          delete_grant(project_id, membership_id, auth)
        else
          nil -> Repo.rollback(missing_resource(project_id, membership_id, auth))
        end
      end)
      |> case do
        {:ok, _grant_or_nil} -> :ok
        {:error, reason} -> {:error, reason}
      end
    else
      :error -> {:error, malformed_resource(project_id, membership_id)}
      {:error, reason} -> {:error, reason}
    end
  end

  def list_team_project_access_grants(project_id, %AuthContext{} = auth) do
    with :ok <- authorize_access_management(auth),
         {:ok, project_id} <- Ecto.UUID.cast(project_id),
         %Project{} <- tenant_project(project_id, auth.organization_id) do
      {:ok,
       Repo.all(
         from grant in TeamProjectAccessGrant,
           where:
             grant.project_id == ^project_id and
               grant.organization_id == ^auth.organization_id,
           order_by: [asc: grant.inserted_at, asc: grant.id]
       )}
    else
      :error -> {:error, :project_not_found}
      nil -> {:error, :project_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def put_team_project_access_grant(project_id, team_id, access, %AuthContext{} = auth) do
    with :ok <- authorize_access_management(auth),
         {:ok, project_id} <- Ecto.UUID.cast(project_id) do
      Repo.transaction(fn ->
        case tenant_project(project_id, auth.organization_id) do
          nil ->
            Repo.rollback(:project_not_found)

          %Project{} ->
            with {:ok, team_id} <- Ecto.UUID.cast(team_id),
                 %Team{} = team <- tenant_team_for_update(team_id, auth.organization_id),
                 :ok <- ensure_team_active(team) do
              put_team_grant(project_id, team_id, access, auth)
            else
              nil -> Repo.rollback(:team_not_found)
              :error -> Repo.rollback(:team_not_found)
              {:error, reason} -> Repo.rollback(reason)
            end
        end
      end)
      |> unwrap_transaction()
    else
      :error -> {:error, :project_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def delete_team_project_access_grant(project_id, team_id, %AuthContext{} = auth) do
    with :ok <- authorize_access_management(auth),
         {:ok, project_id} <- Ecto.UUID.cast(project_id) do
      Repo.transaction(fn ->
        case tenant_project(project_id, auth.organization_id) do
          nil ->
            Repo.rollback(:project_not_found)

          %Project{} ->
            with {:ok, team_id} <- Ecto.UUID.cast(team_id),
                 %Team{} <- tenant_team_for_update(team_id, auth.organization_id) do
              delete_team_grant(project_id, team_id, auth)
            else
              nil -> Repo.rollback(:team_not_found)
              :error -> Repo.rollback(:team_not_found)
            end
        end
      end)
      |> case do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, reason}
      end
    else
      :error -> {:error, :project_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def list_agent_project_access_grants(project_id, %AuthContext{} = auth) do
    with :ok <- authorize_access_management(auth),
         {:ok, project_id} <- Ecto.UUID.cast(project_id),
         %Project{} <- tenant_project(project_id, auth.organization_id) do
      {:ok,
       Repo.all(
         from grant in AgentProjectAccessGrant,
           where:
             grant.project_id == ^project_id and
               grant.organization_id == ^auth.organization_id,
           order_by: [asc: grant.inserted_at, asc: grant.id]
       )}
    else
      :error -> {:error, :project_not_found}
      nil -> {:error, :project_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def put_agent_project_access_grant(project_id, agent_id, access, %AuthContext{} = auth) do
    with :ok <- authorize_access_management(auth),
         {:ok, project_id} <- Ecto.UUID.cast(project_id) do
      Repo.transaction(fn ->
        case tenant_project(project_id, auth.organization_id) do
          nil ->
            Repo.rollback(:project_not_found)

          %Project{} ->
            with {:ok, agent_id} <- Ecto.UUID.cast(agent_id),
                 %Agent{} = agent <- tenant_agent_for_update(agent_id, auth.organization_id),
                 :ok <- ensure_agent_active(agent) do
              put_agent_grant(project_id, agent_id, access, auth)
            else
              :error -> Repo.rollback(:agent_not_found)
              nil -> Repo.rollback(:agent_not_found)
              {:error, reason} -> Repo.rollback(reason)
            end
        end
      end)
      |> unwrap_transaction()
    else
      :error -> {:error, :project_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def delete_agent_project_access_grant(project_id, agent_id, %AuthContext{} = auth) do
    with :ok <- authorize_access_management(auth),
         {:ok, project_id} <- Ecto.UUID.cast(project_id) do
      Repo.transaction(fn ->
        case tenant_project(project_id, auth.organization_id) do
          nil ->
            Repo.rollback(:project_not_found)

          %Project{} ->
            with {:ok, agent_id} <- Ecto.UUID.cast(agent_id),
                 %Agent{} <- tenant_agent_for_update(agent_id, auth.organization_id) do
              delete_agent_grant(project_id, agent_id, auth)
            else
              :error -> Repo.rollback(:agent_not_found)
              nil -> Repo.rollback(:agent_not_found)
            end
        end
      end)
      |> case do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, reason}
      end
    else
      :error -> {:error, :project_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp authorized_project(id, %AuthContext{role: "owner"} = auth, _required_access) do
    tenant_project(id, auth.organization_id)
  end

  defp authorized_project(id, %AuthContext{role: "member"} = auth, required_access) do
    allowed_access =
      case required_access do
        :reader -> @reader_access
        :editor -> @editor_access
      end

    Repo.one(
      from project in Project,
        join: membership in OrganizationMembership,
        on:
          membership.id == ^auth.membership_id and
            membership.organization_id == project.organization_id,
        left_join: grant in ProjectAccessGrant,
        on:
          grant.project_id == project.id and
            grant.organization_id == project.organization_id and
            grant.organization_membership_id == membership.id,
        left_join: link in TeamMembership,
        on:
          link.organization_id == project.organization_id and
            link.organization_membership_id == membership.id,
        left_join: team in Team,
        on:
          team.id == link.team_id and team.organization_id == link.organization_id and
            is_nil(team.deactivated_at),
        left_join: team_grant in TeamProjectAccessGrant,
        on:
          team_grant.project_id == project.id and
            team_grant.organization_id == project.organization_id and
            team_grant.team_id == team.id,
        where:
          project.id == ^id and
            project.organization_id == ^auth.organization_id and
            membership.role == "member" and
            is_nil(membership.deactivated_at) and
            (grant.access in ^allowed_access or team_grant.access in ^allowed_access),
        distinct: true
    )
  end

  defp authorized_project(id, %AuthContext{role: "agent"} = auth, required_access)
       when required_access in [:reader, :editor] do
    allowed_access = if required_access == :reader, do: @reader_access, else: @editor_access

    Repo.one(
      from project in Project,
        join: agent in Agent,
        on:
          agent.id == ^auth.agent_id and
            agent.organization_id == project.organization_id and
            is_nil(agent.deactivated_at),
        join: grant in AgentProjectAccessGrant,
        on:
          grant.project_id == project.id and
            grant.organization_id == project.organization_id and
            grant.agent_id == agent.id and grant.access in ^allowed_access,
        where:
          project.id == ^id and
            project.organization_id == ^auth.organization_id
    )
  end

  defp authorized_project(_id, _auth, _required_access), do: nil

  defp authorize_agent_memory_write(id, auth) do
    with {:ok, id} <- Ecto.UUID.cast(id),
         %Agent{deactivated_at: nil} <-
           tenant_agent_for_update(auth.agent_id, auth.organization_id),
         %ApiToken{} = token <- agent_token_for_update(auth.api_token_id, auth.agent_id),
         true <- active_token?(token),
         %Project{} = project <- tenant_project(id, auth.organization_id),
         %AgentProjectAccessGrant{access: "editor"} <-
           agent_grant_for_update(id, auth.agent_id, auth.organization_id) do
      {:ok, project}
    else
      _missing -> {:error, :project_not_found}
    end
  end

  defp put_grant(project_id, membership_id, access, auth) do
    case project_access_grant_for_update(project_id, membership_id, auth.organization_id) do
      nil ->
        changeset =
          ProjectAccessGrant.changeset(%ProjectAccessGrant{}, %{
            organization_id: auth.organization_id,
            project_id: project_id,
            organization_membership_id: membership_id,
            access: access
          })

        with {:ok, grant} <- Repo.insert(changeset),
             {:ok, _event} <-
               grant_audit_changeset(auth, "project_access.grant", grant)
               |> Repo.insert() do
          grant
        else
          {:error, reason} -> Repo.rollback(reason)
        end

      %ProjectAccessGrant{access: ^access} = grant ->
        grant

      %ProjectAccessGrant{} = grant ->
        previous_access = grant.access

        with {:ok, updated_grant} <-
               grant
               |> ProjectAccessGrant.changeset(%{access: access})
               |> Repo.update(),
             {:ok, _event} <-
               grant_audit_changeset(
                 auth,
                 "project_access.change",
                 updated_grant,
                 %{"previous_access" => previous_access}
               )
               |> Repo.insert() do
          updated_grant
        else
          {:error, reason} -> Repo.rollback(reason)
        end
    end
  end

  defp delete_grant(project_id, membership_id, auth) do
    case project_access_grant_for_update(project_id, membership_id, auth.organization_id) do
      nil ->
        nil

      %ProjectAccessGrant{} = grant ->
        with {:ok, deleted_grant} <- Repo.delete(grant),
             {:ok, _event} <-
               grant_audit_changeset(
                 auth,
                 "project_access.revoke",
                 grant,
                 %{"previous_access" => grant.access}
               )
               |> Repo.insert() do
          deleted_grant
        else
          {:error, reason} -> Repo.rollback(reason)
        end
    end
  end

  defp put_team_grant(project_id, team_id, access, auth) do
    case team_grant_for_update(project_id, team_id, auth.organization_id) do
      nil ->
        changeset =
          TeamProjectAccessGrant.changeset(%TeamProjectAccessGrant{}, %{
            organization_id: auth.organization_id,
            project_id: project_id,
            team_id: team_id,
            access: access
          })

        with {:ok, grant} <- Repo.insert(changeset),
             {:ok, _event} <-
               team_grant_audit_changeset(auth, "team_project_access.grant", grant)
               |> Repo.insert() do
          grant
        else
          {:error, reason} -> Repo.rollback(reason)
        end

      %TeamProjectAccessGrant{access: ^access} = grant ->
        grant

      %TeamProjectAccessGrant{} = grant ->
        previous_access = grant.access

        with {:ok, updated} <-
               grant |> TeamProjectAccessGrant.changeset(%{access: access}) |> Repo.update(),
             {:ok, _event} <-
               team_grant_audit_changeset(
                 auth,
                 "team_project_access.change",
                 updated,
                 %{"previous_access" => previous_access}
               )
               |> Repo.insert() do
          updated
        else
          {:error, reason} -> Repo.rollback(reason)
        end
    end
  end

  defp delete_team_grant(project_id, team_id, auth) do
    case team_grant_for_update(project_id, team_id, auth.organization_id) do
      nil ->
        nil

      grant ->
        with {:ok, deleted} <- Repo.delete(grant),
             {:ok, _event} <-
               team_grant_audit_changeset(
                 auth,
                 "team_project_access.revoke",
                 grant,
                 %{"previous_access" => grant.access}
               )
               |> Repo.insert() do
          deleted
        else
          {:error, reason} -> Repo.rollback(reason)
        end
    end
  end

  defp put_agent_grant(project_id, agent_id, access, auth) do
    case agent_grant_for_update(project_id, agent_id, auth.organization_id) do
      nil ->
        changeset =
          AgentProjectAccessGrant.changeset(%AgentProjectAccessGrant{}, %{
            organization_id: auth.organization_id,
            project_id: project_id,
            agent_id: agent_id,
            access: access
          })

        with {:ok, grant} <- Repo.insert(changeset),
             {:ok, _event} <-
               agent_grant_audit_changeset(auth, "agent_project_access.grant", grant)
               |> Repo.insert() do
          grant
        else
          {:error, reason} -> Repo.rollback(reason)
        end

      %AgentProjectAccessGrant{access: ^access} = grant ->
        grant

      %AgentProjectAccessGrant{} = grant ->
        previous_access = grant.access

        with {:ok, updated} <-
               grant |> AgentProjectAccessGrant.changeset(%{access: access}) |> Repo.update(),
             {:ok, _event} <-
               agent_grant_audit_changeset(
                 auth,
                 "agent_project_access.change",
                 updated,
                 %{"previous_access" => previous_access}
               )
               |> Repo.insert() do
          updated
        else
          {:error, reason} -> Repo.rollback(reason)
        end
    end
  end

  defp delete_agent_grant(project_id, agent_id, auth) do
    case agent_grant_for_update(project_id, agent_id, auth.organization_id) do
      nil ->
        nil

      grant ->
        with {:ok, deleted} <- Repo.delete(grant),
             {:ok, _event} <-
               agent_grant_audit_changeset(
                 auth,
                 "agent_project_access.revoke",
                 grant,
                 %{"previous_access" => grant.access}
               )
               |> Repo.insert() do
          deleted
        else
          {:error, reason} -> Repo.rollback(reason)
        end
    end
  end

  defp agent_grant_audit_changeset(auth, action, grant, metadata \\ %{}) do
    Accounts.audit_changeset(
      auth,
      action,
      "agent_project_access_grant",
      grant.id,
      Map.merge(
        %{
          "project_id" => grant.project_id,
          "agent_id" => grant.agent_id,
          "access" => grant.access
        },
        metadata
      )
    )
  end

  defp team_grant_audit_changeset(auth, action, grant, metadata \\ %{}) do
    Accounts.audit_changeset(
      auth,
      action,
      "team_project_access_grant",
      grant.id,
      Map.merge(
        %{
          "project_id" => grant.project_id,
          "team_id" => grant.team_id,
          "access" => grant.access
        },
        metadata
      )
    )
  end

  defp grant_audit_changeset(auth, action, grant, metadata \\ %{}) do
    Accounts.audit_changeset(
      auth,
      action,
      "project_access_grant",
      grant.id,
      Map.merge(
        %{
          "project_id" => grant.project_id,
          "membership_id" => grant.organization_membership_id,
          "access" => grant.access
        },
        metadata
      )
    )
  end

  defp authorize_access_management(%AuthContext{role: "owner"} = auth) do
    if Accounts.authorized?(auth, "projects.manage_access"),
      do: :ok,
      else: {:error, :forbidden}
  end

  defp authorize_access_management(_auth), do: {:error, :forbidden}

  defp tenant_project(id, organization_id) do
    Repo.one(
      from project in Project,
        where: project.id == ^id and project.organization_id == ^organization_id
    )
  end

  defp tenant_membership_for_update(id, organization_id) do
    Repo.one(
      from membership in OrganizationMembership,
        where:
          membership.id == ^id and
            membership.organization_id == ^organization_id,
        lock: "FOR UPDATE"
    )
  end

  defp project_access_grant_for_update(project_id, membership_id, organization_id) do
    Repo.one(
      from grant in ProjectAccessGrant,
        where:
          grant.project_id == ^project_id and
            grant.organization_membership_id == ^membership_id and
            grant.organization_id == ^organization_id,
        lock: "FOR UPDATE"
    )
  end

  defp tenant_team_for_update(id, organization_id) do
    Repo.one(
      from team in Team,
        where: team.id == ^id and team.organization_id == ^organization_id,
        lock: "FOR UPDATE"
    )
  end

  defp team_grant_for_update(project_id, team_id, organization_id) do
    Repo.one(
      from grant in TeamProjectAccessGrant,
        where:
          grant.project_id == ^project_id and grant.team_id == ^team_id and
            grant.organization_id == ^organization_id,
        lock: "FOR UPDATE"
    )
  end

  defp tenant_agent_for_update(id, organization_id) do
    Repo.one(
      from agent in Agent,
        where: agent.id == ^id and agent.organization_id == ^organization_id,
        lock: "FOR UPDATE"
    )
  end

  defp agent_grant_for_update(project_id, agent_id, organization_id) do
    Repo.one(
      from grant in AgentProjectAccessGrant,
        where:
          grant.project_id == ^project_id and grant.agent_id == ^agent_id and
            grant.organization_id == ^organization_id,
        lock: "FOR UPDATE"
    )
  end

  defp agent_token_for_update(token_id, agent_id) do
    Repo.one(
      from token in ApiToken,
        where: token.id == ^token_id and token.agent_id == ^agent_id,
        lock: "FOR UPDATE"
    )
  end

  defp active_token?(%ApiToken{revoked_at: revoked_at, expires_at: expires_at}) do
    is_nil(revoked_at) and
      (is_nil(expires_at) or DateTime.after?(expires_at, DateTime.utc_now()))
  end

  defp ensure_membership_active(%OrganizationMembership{deactivated_at: nil}), do: :ok
  defp ensure_membership_active(_membership), do: {:error, :membership_inactive}
  defp ensure_team_active(%Team{deactivated_at: nil}), do: :ok
  defp ensure_team_active(_team), do: {:error, :team_inactive}
  defp ensure_agent_active(%Agent{deactivated_at: nil}), do: :ok
  defp ensure_agent_active(_agent), do: {:error, :agent_inactive}

  defp malformed_resource(project_id, _membership_id) do
    if Ecto.UUID.cast(project_id) == :error,
      do: :project_not_found,
      else: :membership_not_found
  end

  defp missing_resource(project_id, membership_id, auth) do
    cond do
      is_nil(tenant_project(project_id, auth.organization_id)) ->
        :project_not_found

      is_nil(tenant_membership_for_update(membership_id, auth.organization_id)) ->
        :membership_not_found
    end
  end

  defp unwrap_transaction({:ok, value}), do: {:ok, value}
  defp unwrap_transaction({:error, reason}), do: {:error, reason}

  defp attribute(attrs, key) do
    Map.get(attrs, key, Map.get(attrs, Atom.to_string(key)))
  end
end
