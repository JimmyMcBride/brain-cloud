defmodule BrainCloudWeb.SearchController do
  use BrainCloudWeb, :controller

  alias BrainCloud.Memories
  alias BrainCloudWeb.APIError
  alias BrainCloudWeb.APIJSON

  def index(conn, %{"project_id" => project_id} = params) do
    case Memories.search(project_id, Map.get(params, "q")) do
      {:ok, results} ->
        json(conn, %{results: Enum.map(results, &APIJSON.search_result/1)})

      {:error, :project_not_found} ->
        APIError.project_not_found(conn)

      {:error, {:validation_failed, details}} ->
        APIError.validation_failed(conn, details)
    end
  end
end
