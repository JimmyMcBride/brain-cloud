defmodule BrainCloudWeb.BrowserInvitationController do
  use BrainCloudWeb, :controller
  alias BrainCloud.Accounts
  alias BrainCloud.Accounts.InvitationDelivery
  alias BrainCloudWeb.{BrowserAuth, UserNotifier}
  require Logger

  plug :private_response
  plug :owner_scope when action in [:index, :create, :send_invitation, :revoke]

  def index(conn, _params) do
    case InvitationDelivery.list(BrowserAuth.session_token(conn)) do
      {:ok, invitations} -> render(conn, :index, invitations: invitations)
      {:error, reason} -> failure(conn, reason)
    end
  end

  def create(conn, params) do
    result =
      InvitationDelivery.create(
        BrowserAuth.session_token(conn),
        invitation_params(params)
      )

    delivery_response(conn, result)
  end

  def send_invitation(conn, %{"id" => id}) do
    delivery_response(conn, InvitationDelivery.reserve(BrowserAuth.session_token(conn), id))
  end

  def revoke(conn, %{"id" => id}) do
    case InvitationDelivery.revoke(BrowserAuth.session_token(conn), id) do
      {:ok, :ok} ->
        back(conn, "Invitation revoked. Previously accepted memberships are unchanged.")

      {:error, reason} ->
        failure(conn, reason)
    end
  end

  def landing(conn, _params), do: render(conn, :landing)

  def preview(conn, params) do
    token = Map.get(invitation_params(params), "token")

    case Accounts.preview_browser_invitation(token, BrowserAuth.session_token(conn)) do
      {:ok, invitation} -> render(conn, :preview, invitation: invitation, token: token)
      {:error, reason} -> failure(conn, reason)
    end
  end

  def accept(conn, params) do
    token = Map.get(invitation_params(params), "token")

    case Accounts.accept_browser_invitation(token, BrowserAuth.session_token(conn)) do
      {:ok, _result} ->
        target = if conn.assigns.current_scope, do: ~p"/", else: ~p"/sign-in"

        conn
        |> put_flash(
          :info,
          "You joined the organization. Sign in with your invited email to continue."
        )
        |> put_status(:see_other)
        |> redirect(to: target)

      {:error, reason} ->
        failure(conn, reason)
    end
  end

  defp delivery_response(conn, {:ok, reservation}) do
    outcome = deliver(reservation)
    result = safely_finish(reservation.attempt.id, outcome)

    message =
      case result do
        {:ok, :sent} ->
          "Invitation accepted by the mail server. Delivery to the inbox is not guaranteed."

        {:ok, :stale} ->
          "Invitation changed while sending. Refresh before trying again."

        _ ->
          "Email could not be confirmed. The invitation remains pending; retry after the cooldown."
      end

    back(conn, message)
  end

  defp delivery_response(conn, {:error, reason}), do: failure(conn, reason)

  defp deliver(reservation) do
    case UserNotifier.deliver_invitation(reservation.invitation, reservation.token) do
      {:ok, _} -> :sent
      _ -> :failed
    end
  rescue
    _ -> :failed
  catch
    _, _ -> :failed
  end

  defp safely_finish(id, outcome) do
    InvitationDelivery.finish(id, outcome)
  rescue
    _ ->
      Logger.error("invitation delivery finalization failed", attempt_id: id)
      {:error, :delivery_failed}
  catch
    _, _ -> {:error, :delivery_failed}
  end

  defp back(conn, message),
    do:
      conn
      |> put_flash(:info, message)
      |> put_status(:see_other)
      |> redirect(to: ~p"/organization/invitations")

  defp failure(conn, {:throttled, seconds}) do
    conn
    |> put_resp_header("retry-after", Integer.to_string(seconds))
    |> put_status(429)
    |> render(:error, message: "Too many invitation attempts. Try again in #{seconds} seconds.")
  end

  defp failure(conn, %Ecto.Changeset{}),
    do:
      conn
      |> put_status(422)
      |> render(:error, message: "Enter a valid email and a display name of 1–120 characters.")

  defp failure(conn, reason) when reason in [:membership_exists, :invitation_exists],
    do:
      conn
      |> put_status(409)
      |> render(:error,
        message:
          "This invitation conflicts with an existing membership or pending invitation. No membership was changed."
      )

  defp failure(conn, :identity_mismatch),
    do:
      conn
      |> put_status(409)
      |> render(:error,
        message:
          "This invitation is for a different email. Sign out, then reopen the original email link."
      )

  defp failure(conn, :unauthorized),
    do: conn |> put_status(:see_other) |> redirect(to: ~p"/sign-in")

  defp failure(conn, _),
    do:
      conn
      |> put_status(404)
      |> render(:error,
        message:
          "This invitation is unavailable. It may be invalid, expired, or no longer usable."
      )

  defp owner_scope(conn, _) do
    case conn.assigns.current_scope do
      nil -> conn |> redirect(to: ~p"/sign-in") |> halt()
      %{selected_membership: nil} -> conn |> redirect(to: ~p"/") |> halt()
      %{role: "owner"} -> conn
      _ -> conn |> failure(:invitation_not_found) |> halt()
    end
  end

  defp private_response(conn, _),
    do:
      conn
      |> put_resp_header("cache-control", "no-store")
      |> put_resp_header("referrer-policy", "no-referrer")

  defp invitation_params(%{"invitation" => attrs}) when is_map(attrs), do: attrs
  defp invitation_params(_), do: %{}
end
