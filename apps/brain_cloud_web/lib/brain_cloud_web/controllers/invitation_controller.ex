defmodule BrainCloudWeb.InvitationController do
  use BrainCloudWeb, :controller

  alias BrainCloud.Accounts
  alias BrainCloudWeb.APIError
  alias BrainCloudWeb.APIJSON

  plug BrainCloudWeb.Plugs.RequireOwner
  plug BrainCloudWeb.Plugs.RequireScope, scope: "members.manage"
  plug BrainCloudWeb.Plugs.RequireScope, [scope: "tokens.manage"] when action in [:create]

  def create(conn, params) do
    case Accounts.create_organization_invitation(conn.assigns.auth_context, params) do
      {:ok, invitation, raw_token} ->
        conn
        |> put_status(:created)
        |> json(%{
          invitation: APIJSON.invitation(invitation),
          acceptance_token: raw_token
        })

      {:error, reason} ->
        render_error(conn, reason)
    end
  end

  def index(conn, _params) do
    case Accounts.list_organization_invitations(conn.assigns.auth_context) do
      {:ok, invitations} ->
        json(conn, %{invitations: Enum.map(invitations, &APIJSON.invitation/1)})

      {:error, reason} ->
        render_error(conn, reason)
    end
  end

  def delete(conn, %{"id" => invitation_id}) do
    case Accounts.revoke_organization_invitation(conn.assigns.auth_context, invitation_id) do
      {:ok, :ok} -> send_resp(conn, :no_content, "")
      {:error, reason} -> render_error(conn, reason)
    end
  end

  defp render_error(conn, :forbidden), do: APIError.forbidden(conn)
  defp render_error(conn, :membership_exists), do: APIError.membership_exists(conn)
  defp render_error(conn, :invitation_exists), do: APIError.invitation_exists(conn)
  defp render_error(conn, :invitation_not_found), do: APIError.invitation_not_found(conn)

  defp render_error(conn, %Ecto.Changeset{} = changeset),
    do: APIError.validation_failed(conn, changeset)
end
