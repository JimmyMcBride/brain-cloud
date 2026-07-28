defmodule BrainCloud.Projects do
  @moduledoc """
  Creates and retrieves cloud-native projects.
  """

  alias BrainCloud.Projects.Project
  alias BrainCloud.Repo

  def create_project(attrs, actor_id) do
    attrs = Map.new(attrs)

    %{
      name: attribute(attrs, :name),
      creator_actor_id: actor_id
    }
    |> then(&Project.changeset(%Project{}, &1))
    |> Repo.insert()
  end

  def get_project(id) do
    case Ecto.UUID.cast(id) do
      {:ok, id} -> Repo.get(Project, id)
      :error -> nil
    end
  end

  defp attribute(attrs, key) do
    Map.get(attrs, key, Map.get(attrs, Atom.to_string(key)))
  end
end
