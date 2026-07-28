defmodule BrainCloudWeb.MemoryController do
  use BrainCloudWeb, :controller

  alias BrainCloud.Memories
  alias BrainCloud.Projects
  alias BrainCloudWeb.APIError
  alias BrainCloudWeb.APIJSON

  plug BrainCloudWeb.Plugs.RequireScope, [scope: "memory.write"] when action in [:create]
  plug BrainCloudWeb.Plugs.RequireScope, [scope: "memory.read"] when action in [:show]

  def create(conn, %{"project_id" => project_id} = params) do
    case Memories.create_memory(project_id, params, conn.assigns.auth_context) do
      {:ok, memory} ->
        conn
        |> put_status(:created)
        |> json(%{memory: APIJSON.memory(memory)})

      {:error, :project_not_found} ->
        APIError.project_not_found(conn)

      {:error, changeset} ->
        APIError.validation_failed(conn, changeset)
    end
  end

  def show(conn, %{"project_id" => project_id, "id" => memory_id}) do
    organization_id = conn.assigns.auth_context.organization_id

    cond do
      is_nil(Projects.get_project(project_id, organization_id)) ->
        APIError.project_not_found(conn)

      memory = Memories.get_memory(project_id, memory_id, organization_id) ->
        json(conn, %{memory: APIJSON.memory(memory)})

      true ->
        APIError.memory_not_found(conn)
    end
  end
end
