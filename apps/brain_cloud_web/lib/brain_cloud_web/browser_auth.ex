defmodule BrainCloudWeb.BrowserAuth do
  @moduledoc false

  use BrainCloudWeb, :verified_routes

  import Plug.Conn
  import Plug.CSRFProtection, only: [delete_csrf_token: 0]

  alias BrainCloud.Accounts

  @session_key "browser_session_token"

  def init(opts), do: opts
  def call(conn, _opts), do: fetch_current_scope(conn, [])

  def fetch_current_scope(conn, _opts) do
    case get_session(conn, @session_key) do
      raw_token when is_binary(raw_token) -> load_scope(conn, raw_token)
      _missing -> assign(conn, :current_scope, nil)
    end
  end

  def on_mount(:current_scope, _params, session, socket) do
    scope =
      case session[@session_key] do
        raw_token when is_binary(raw_token) ->
          case Accounts.authenticate_browser_session(raw_token, rotate: false) do
            {:ok, scope, nil} -> scope
            {:error, :unauthorized} -> nil
          end

        _missing ->
          nil
      end

    {:cont, Phoenix.Component.assign(socket, :current_scope, scope)}
  end

  def put_browser_session(conn, raw_token) do
    conn
    |> renew_session()
    |> put_session(@session_key, raw_token)
  end

  def clear_browser_session(conn) do
    conn
    |> renew_session()
    |> delete_session(@session_key)
  end

  def session_token(conn), do: get_session(conn, @session_key)

  defp load_scope(conn, raw_token) do
    case Accounts.authenticate_browser_session(raw_token) do
      {:ok, scope, nil} ->
        assign(conn, :current_scope, scope)

      {:ok, scope, replacement_token} ->
        conn
        |> renew_session()
        |> put_session(@session_key, replacement_token)
        |> assign(:current_scope, scope)

      {:error, :unauthorized} ->
        conn
        |> delete_session(@session_key)
        |> assign(:current_scope, nil)
    end
  end

  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end
end
