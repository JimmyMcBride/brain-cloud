defmodule BrainCloudWeb.BrowserSessionController do
  use BrainCloudWeb, :controller

  alias BrainCloud.Accounts
  alias BrainCloudWeb.BrowserAuth

  def delete(conn, _params) do
    Accounts.logout_browser_session(BrowserAuth.session_token(conn))

    conn
    |> BrowserAuth.clear_browser_session()
    |> put_flash(:info, "Signed out.")
    |> redirect(to: ~p"/")
  end
end
