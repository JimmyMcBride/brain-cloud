defmodule BrainCloudWeb.AgentTokenController do
  use BrainCloudWeb, :controller

  alias BrainCloud.Agents
  alias BrainCloudWeb.APIError
  alias BrainCloudWeb.APIJSON

  plug BrainCloudWeb.Plugs.RequireOwner
  plug BrainCloudWeb.Plugs.RequireScope, scope: "agents.manage"

  def create(conn, %{"agent_id" => agent_id} = params) do
    case Agents.create_agent_token(agent_id, params, conn.assigns.auth_context) do
      {:ok, token, raw_token} ->
        conn
        |> put_status(:created)
        |> json(%{token: APIJSON.created_token(token, raw_token)})

      {:error, reason} ->
        render_error(conn, reason)
    end
  end

  def index(conn, %{"agent_id" => agent_id}) do
    case Agents.list_agent_tokens(agent_id, conn.assigns.auth_context) do
      {:ok, tokens} -> json(conn, %{tokens: Enum.map(tokens, &APIJSON.token/1)})
      {:error, reason} -> render_error(conn, reason)
    end
  end

  def delete(conn, %{"agent_id" => agent_id, "id" => token_id}) do
    case Agents.revoke_agent_token(agent_id, token_id, conn.assigns.auth_context) do
      :ok -> send_resp(conn, :no_content, "")
      {:error, reason} -> render_error(conn, reason)
    end
  end

  defp render_error(conn, :forbidden), do: APIError.forbidden(conn)
  defp render_error(conn, :agent_not_found), do: APIError.agent_not_found(conn)
  defp render_error(conn, :agent_inactive), do: APIError.agent_inactive(conn)
  defp render_error(conn, :token_not_found), do: APIError.token_not_found(conn)

  defp render_error(conn, %Ecto.Changeset{} = changeset),
    do: APIError.validation_failed(conn, changeset)
end
