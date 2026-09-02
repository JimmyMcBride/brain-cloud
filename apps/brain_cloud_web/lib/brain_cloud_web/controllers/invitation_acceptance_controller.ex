defmodule BrainCloudWeb.InvitationAcceptanceController do
  use BrainCloudWeb, :controller

  alias BrainCloud.Accounts
  alias BrainCloudWeb.APIError
  alias BrainCloudWeb.APIJSON

  def create(conn, %{"acceptance_token" => acceptance_token}) do
    case Accounts.accept_organization_invitation(acceptance_token) do
      {:ok, result} ->
        conn
        |> put_status(:created)
        |> json(%{
          membership: APIJSON.membership(result.membership),
          token: APIJSON.created_token(result.token, result.raw_token)
        })

      {:error, reason} ->
        render_error(conn, reason)
    end
  end

  def create(conn, _params), do: APIError.invitation_not_found(conn)

  defp render_error(conn, :invitation_not_found), do: APIError.invitation_not_found(conn)
  defp render_error(conn, :membership_exists), do: APIError.membership_exists(conn)

  defp render_error(conn, %Ecto.Changeset{} = changeset),
    do: APIError.validation_failed(conn, changeset)
end
