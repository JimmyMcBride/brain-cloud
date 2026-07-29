defmodule BrainCloudWeb.TeamController do
  use BrainCloudWeb, :controller

  alias BrainCloud.Teams
  alias BrainCloudWeb.APIError
  alias BrainCloudWeb.APIJSON

  plug BrainCloudWeb.Plugs.RequireOwner
  plug BrainCloudWeb.Plugs.RequireScope, scope: "teams.manage"

  def create(conn, params) do
    case Teams.create_team(params, conn.assigns.auth_context) do
      {:ok, team} -> conn |> put_status(:created) |> json(%{team: APIJSON.team(team)})
      {:error, reason} -> render_error(conn, reason)
    end
  end

  def index(conn, _params) do
    case Teams.list_teams(conn.assigns.auth_context) do
      {:ok, teams} -> json(conn, %{teams: Enum.map(teams, &APIJSON.team/1)})
      {:error, reason} -> render_error(conn, reason)
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Teams.rename_team(id, Map.get(params, "name"), conn.assigns.auth_context) do
      {:ok, team} -> json(conn, %{team: APIJSON.team(team)})
      {:error, reason} -> render_error(conn, reason)
    end
  end

  def delete(conn, %{"id" => id}) do
    case Teams.deactivate_team(id, conn.assigns.auth_context) do
      {:ok, _team} -> send_resp(conn, :no_content, "")
      {:error, reason} -> render_error(conn, reason)
    end
  end

  def reactivate(conn, %{"id" => id}) do
    case Teams.reactivate_team(id, conn.assigns.auth_context) do
      {:ok, team} -> json(conn, %{team: APIJSON.team(team)})
      {:error, reason} -> render_error(conn, reason)
    end
  end

  defp render_error(conn, :forbidden), do: APIError.forbidden(conn)
  defp render_error(conn, :team_not_found), do: APIError.team_not_found(conn)

  defp render_error(conn, %Ecto.Changeset{} = changeset),
    do: APIError.validation_failed(conn, changeset)
end
