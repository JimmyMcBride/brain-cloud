defmodule BrainCloudWeb.MembershipController do
  use BrainCloudWeb, :controller

  alias BrainCloud.Accounts
  alias BrainCloudWeb.APIError
  alias BrainCloudWeb.APIJSON

  plug BrainCloudWeb.Plugs.RequireOwner
  plug BrainCloudWeb.Plugs.RequireScope, scope: "members.manage"
  plug BrainCloudWeb.Plugs.RequireScope, [scope: "tokens.manage"] when action in [:create_token]

  def create(conn, params) do
    case Accounts.create_organization_membership(conn.assigns.auth_context, params) do
      {:ok, membership} ->
        conn
        |> put_status(:created)
        |> json(%{membership: APIJSON.membership(membership)})

      {:error, reason} ->
        render_error(conn, reason)
    end
  end

  def index(conn, _params) do
    case Accounts.list_organization_memberships(conn.assigns.auth_context) do
      {:ok, memberships} ->
        json(conn, %{memberships: Enum.map(memberships, &APIJSON.membership/1)})

      {:error, reason} ->
        render_error(conn, reason)
    end
  end

  def update(conn, %{"id" => membership_id} = params) do
    case Accounts.update_organization_membership_role(
           conn.assigns.auth_context,
           membership_id,
           Map.get(params, "role")
         ) do
      {:ok, membership} ->
        json(conn, %{membership: APIJSON.membership(membership)})

      {:error, reason} ->
        render_error(conn, reason)
    end
  end

  def delete(conn, %{"id" => membership_id}) do
    case Accounts.deactivate_organization_membership(
           conn.assigns.auth_context,
           membership_id
         ) do
      {:ok, _membership} ->
        send_resp(conn, :no_content, "")

      {:error, reason} ->
        render_error(conn, reason)
    end
  end

  def reactivate(conn, %{"id" => membership_id}) do
    case Accounts.reactivate_organization_membership(
           conn.assigns.auth_context,
           membership_id
         ) do
      {:ok, membership} ->
        json(conn, %{membership: APIJSON.membership(membership)})

      {:error, reason} ->
        render_error(conn, reason)
    end
  end

  def create_token(conn, %{"id" => membership_id} = params) do
    case Accounts.create_membership_api_token(
           conn.assigns.auth_context,
           membership_id,
           params
         ) do
      {:ok, token, raw_token} ->
        conn
        |> put_status(:created)
        |> json(%{token: APIJSON.created_token(token, raw_token)})

      {:error, reason} ->
        render_error(conn, reason)
    end
  end

  defp render_error(conn, :forbidden), do: APIError.forbidden(conn)
  defp render_error(conn, :membership_not_found), do: APIError.membership_not_found(conn)
  defp render_error(conn, :membership_exists), do: APIError.membership_exists(conn)
  defp render_error(conn, :membership_inactive), do: APIError.membership_inactive(conn)
  defp render_error(conn, :last_owner_required), do: APIError.last_owner_required(conn)

  defp render_error(conn, %Ecto.Changeset{} = changeset),
    do: APIError.validation_failed(conn, changeset)
end
