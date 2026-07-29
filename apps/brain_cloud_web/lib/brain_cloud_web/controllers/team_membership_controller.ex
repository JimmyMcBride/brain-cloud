defmodule BrainCloudWeb.TeamMembershipController do
  use BrainCloudWeb, :controller

  alias BrainCloud.Teams
  alias BrainCloudWeb.APIError
  alias BrainCloudWeb.APIJSON

  plug BrainCloudWeb.Plugs.RequireOwner
  plug BrainCloudWeb.Plugs.RequireScope, scope: "teams.manage"

  def index(conn, %{"team_id" => team_id}) do
    case Teams.list_team_memberships(team_id, conn.assigns.auth_context) do
      {:ok, links} ->
        json(conn, %{team_memberships: Enum.map(links, &APIJSON.team_membership/1)})

      {:error, reason} ->
        render_error(conn, reason)
    end
  end

  def update(conn, %{"team_id" => team_id, "membership_id" => membership_id}) do
    case Teams.put_team_membership(team_id, membership_id, conn.assigns.auth_context) do
      {:ok, link} -> json(conn, %{team_membership: APIJSON.team_membership(link)})
      {:error, reason} -> render_error(conn, reason)
    end
  end

  def delete(conn, %{"team_id" => team_id, "membership_id" => membership_id}) do
    case Teams.delete_team_membership(team_id, membership_id, conn.assigns.auth_context) do
      :ok -> send_resp(conn, :no_content, "")
      {:error, reason} -> render_error(conn, reason)
    end
  end

  defp render_error(conn, :forbidden), do: APIError.forbidden(conn)
  defp render_error(conn, :team_not_found), do: APIError.team_not_found(conn)
  defp render_error(conn, :membership_not_found), do: APIError.membership_not_found(conn)
  defp render_error(conn, :team_inactive), do: APIError.team_inactive(conn)
  defp render_error(conn, :membership_inactive), do: APIError.membership_inactive(conn)

  defp render_error(conn, %Ecto.Changeset{} = changeset),
    do: APIError.validation_failed(conn, changeset)
end
