defmodule BrainCloudWeb.ProjectController do
  use BrainCloudWeb, :controller

  alias BrainCloud.Projects
  alias BrainCloudWeb.APIError
  alias BrainCloudWeb.APIJSON

  plug BrainCloudWeb.Plugs.RequireScope, scope: "projects.create"

  def create(conn, params) do
    case Projects.create_project(params, conn.assigns.auth_context) do
      {:ok, project} ->
        conn
        |> put_status(:created)
        |> json(%{project: APIJSON.project(project)})

      {:error, changeset} ->
        APIError.validation_failed(conn, changeset)
    end
  end
end
