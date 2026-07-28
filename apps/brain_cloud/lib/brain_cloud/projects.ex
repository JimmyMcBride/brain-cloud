defmodule BrainCloud.Projects do
  @moduledoc """
  Creates and retrieves cloud-native projects.
  """

  import Ecto.Query

  alias BrainCloud.Accounts
  alias BrainCloud.Accounts.AuthContext
  alias BrainCloud.Projects.Project
  alias BrainCloud.Repo
  alias Ecto.Multi

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
    |> Multi.insert(:audit_event, fn %{project: project} ->
      Accounts.audit_changeset(auth, "project.create", "project", project.id)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{project: project}} -> {:ok, project}
      {:error, :project, changeset, _changes} -> {:error, changeset}
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

  defp attribute(attrs, key) do
    Map.get(attrs, key, Map.get(attrs, Atom.to_string(key)))
  end
end
