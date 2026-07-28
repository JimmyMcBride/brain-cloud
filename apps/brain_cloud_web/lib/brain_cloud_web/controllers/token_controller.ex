defmodule BrainCloudWeb.TokenController do
  use BrainCloudWeb, :controller

  alias BrainCloud.Accounts
  alias BrainCloudWeb.APIError
  alias BrainCloudWeb.APIJSON

  plug BrainCloudWeb.Plugs.RequireScope, scope: "tokens.manage"

  def create(conn, params) do
    case Accounts.create_api_token(conn.assigns.auth_context, params) do
      {:ok, token, raw_token} ->
        conn
        |> put_status(:created)
        |> json(%{token: APIJSON.created_token(token, raw_token)})

      {:error, :forbidden} ->
        APIError.forbidden(conn)

      {:error, changeset} ->
        APIError.validation_failed(conn, changeset)
    end
  end

  def index(conn, _params) do
    case Accounts.list_api_tokens(conn.assigns.auth_context) do
      {:ok, tokens} ->
        json(conn, %{tokens: Enum.map(tokens, &APIJSON.token/1)})

      {:error, :forbidden} ->
        APIError.forbidden(conn)
    end
  end

  def delete(conn, %{"id" => token_id}) do
    case Accounts.revoke_api_token(conn.assigns.auth_context, token_id) do
      {:ok, _token} ->
        send_resp(conn, :no_content, "")

      {:error, :forbidden} ->
        APIError.forbidden(conn)

      {:error, :token_not_found} ->
        APIError.token_not_found(conn)

      {:error, changeset} ->
        APIError.validation_failed(conn, changeset)
    end
  end
end
