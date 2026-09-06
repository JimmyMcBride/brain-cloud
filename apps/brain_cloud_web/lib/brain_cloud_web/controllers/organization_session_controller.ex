defmodule BrainCloudWeb.OrganizationSessionController do
  use BrainCloudWeb, :controller

  alias BrainCloud.Accounts
  alias BrainCloudWeb.BrowserAuth

  def update(conn, %{"membership_id" => membership_id}) do
    case Accounts.select_browser_membership(BrowserAuth.session_token(conn), membership_id) do
      {:ok, _scope} ->
        redirect(conn, to: ~p"/")

      {:error, :unauthorized} ->
        conn
        |> put_flash(:error, "That organization is not available.")
        |> redirect(to: ~p"/")
    end
  end

  def update(conn, _params), do: redirect(conn, to: ~p"/")
end
