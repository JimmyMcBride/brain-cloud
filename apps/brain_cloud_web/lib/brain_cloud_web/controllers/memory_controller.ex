defmodule BrainCloudWeb.MemoryController do
  use BrainCloudWeb, :controller

  alias BrainCloud.Memories
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

      {:error, :forbidden} ->
        APIError.forbidden(conn)

      {:error, changeset} ->
        APIError.validation_failed(conn, changeset)
    end
  end

  def show(conn, %{"project_id" => project_id, "id" => memory_id}) do
    case Memories.get_memory(project_id, memory_id, conn.assigns.auth_context) do
      {:ok, memory} ->
        json(conn, %{memory: APIJSON.memory(memory)})

      {:error, :project_not_found} ->
        APIError.project_not_found(conn)

      {:error, :memory_not_found} ->
        APIError.memory_not_found(conn)
    end
  end
end
