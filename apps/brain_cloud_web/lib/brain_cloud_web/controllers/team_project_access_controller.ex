defmodule BrainCloudWeb.TeamProjectAccessController do
  use BrainCloudWeb, :controller

  alias BrainCloud.Projects
  alias BrainCloudWeb.APIError
  alias BrainCloudWeb.APIJSON

  plug BrainCloudWeb.Plugs.RequireOwner
  plug BrainCloudWeb.Plugs.RequireScope, scope: "projects.manage_access"

  def index(conn, %{"project_id" => project_id}) do
    case Projects.list_team_project_access_grants(project_id, conn.assigns.auth_context) do
      {:ok, grants} ->
        json(conn, %{team_access_grants: Enum.map(grants, &APIJSON.team_project_access_grant/1)})

      {:error, reason} ->
        render_error(conn, reason)
    end
  end

  def update(conn, %{"project_id" => project_id, "team_id" => team_id} = params) do
    case Projects.put_team_project_access_grant(
           project_id,
           team_id,
           Map.get(params, "access"),
           conn.assigns.auth_context
         ) do
      {:ok, grant} ->
        json(conn, %{team_access_grant: APIJSON.team_project_access_grant(grant)})

      {:error, reason} ->
        render_error(conn, reason)
    end
  end

  def delete(conn, %{"project_id" => project_id, "team_id" => team_id}) do
    case Projects.delete_team_project_access_grant(
           project_id,
           team_id,
           conn.assigns.auth_context
         ) do
      :ok -> send_resp(conn, :no_content, "")
      {:error, reason} -> render_error(conn, reason)
    end
  end

  defp render_error(conn, :forbidden), do: APIError.forbidden(conn)
  defp render_error(conn, :project_not_found), do: APIError.project_not_found(conn)
  defp render_error(conn, :team_not_found), do: APIError.team_not_found(conn)
  defp render_error(conn, :team_inactive), do: APIError.team_inactive(conn)

  defp render_error(conn, %Ecto.Changeset{} = changeset),
    do: APIError.validation_failed(conn, changeset)
end
