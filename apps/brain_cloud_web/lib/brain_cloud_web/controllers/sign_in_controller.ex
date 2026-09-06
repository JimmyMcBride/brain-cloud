defmodule BrainCloudWeb.SignInController do
  use BrainCloudWeb, :controller

  require Logger

  alias BrainCloud.Accounts
  alias BrainCloudWeb.BrowserAuth
  alias BrainCloudWeb.UserNotifier

  @acknowledgement "If this email can sign in, a link is on its way."

  def new(conn, _params), do: render(conn, :new)

  def create(conn, %{"sign_in" => %{"email" => email}}) do
    email
    |> Accounts.request_browser_login()
    |> deliver_login()

    render(conn, :accepted, acknowledgement: @acknowledgement)
  end

  def create(conn, _params) do
    Accounts.request_browser_login(nil)
    render(conn, :accepted, acknowledgement: @acknowledgement)
  end

  def confirm(conn, _params), do: render(conn, :confirm)

  def consume(conn, %{"login" => %{"token" => raw_token}}) do
    case Accounts.confirm_browser_login(raw_token) do
      {:ok, _scope, browser_session_token} ->
        conn
        |> BrowserAuth.put_browser_session(browser_session_token)
        |> redirect(to: ~p"/")

      {:error, :login_unavailable} ->
        conn
        |> put_flash(:error, "This sign-in link is invalid or has expired. Request a new one.")
        |> redirect(to: ~p"/sign-in")
    end
  end

  def consume(conn, _params) do
    conn
    |> put_flash(:error, "This sign-in link is invalid or has expired. Request a new one.")
    |> redirect(to: ~p"/sign-in")
  end

  defp deliver_login({:ok, :accepted}), do: :ok

  defp deliver_login({:ok, {:deliver, challenge, raw_token, user}}) do
    safely_deliver(user, raw_token)
    |> case do
      {:ok, _email} ->
        case Accounts.mark_browser_login_sent(challenge.id) do
          {:ok, _sent} -> :ok
          {:error, _reason} -> delivery_failed(challenge.id)
        end

      {:error, _reason} ->
        delivery_failed(challenge.id)
    end
  end

  defp deliver_login({:error, _reason}) do
    Logger.error("browser sign-in request failed")
    :ok
  end

  defp safely_deliver(user, raw_token) do
    raw_token
    |> UserNotifier.sign_in_url()
    |> then(&UserNotifier.deliver_sign_in_link(user, &1))
  rescue
    _error -> {:error, :delivery_failed}
  catch
    _kind, _reason -> {:error, :delivery_failed}
  end

  defp delivery_failed(challenge_id) do
    Accounts.invalidate_browser_login(challenge_id)
    Logger.error("browser sign-in delivery failed", challenge_id: challenge_id)
    :ok
  end
end
