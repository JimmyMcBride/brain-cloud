defmodule BrainCloud.Projects do
  @moduledoc """
  Creates and retrieves cloud-native projects.
  """

  import Ecto.Query

  alias BrainCloud.Accounts
  alias BrainCloud.Accounts.AuthContext
  alias BrainCloud.Accounts.OrganizationMembership
  alias BrainCloud.Projects.Project
  alias BrainCloud.Projects.ProjectAccessGrant
  alias BrainCloud.Repo
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
        join: grant in ProjectAccessGrant,
        on:
          grant.project_id == project.id and
            grant.organization_id == project.organization_id,
        join: membership in OrganizationMembership,
        on:
          membership.id == grant.organization_membership_id and
            membership.organization_id == grant.organization_id,
        where:
          project.id == ^id and
            project.organization_id == ^auth.organization_id and
            grant.organization_membership_id == ^auth.membership_id and
            grant.access in ^allowed_access and
            membership.role == "member" and
            is_nil(membership.deactivated_at)
    )
  end

  defp authorized_project(_id, _auth, _required_access), do: nil

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

  defp ensure_membership_active(%OrganizationMembership{deactivated_at: nil}), do: :ok
  defp ensure_membership_active(_membership), do: {:error, :membership_inactive}

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
