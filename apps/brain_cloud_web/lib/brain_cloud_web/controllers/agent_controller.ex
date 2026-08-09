defmodule BrainCloudWeb.AgentController do
  use BrainCloudWeb, :controller

  alias BrainCloud.Agents
  alias BrainCloudWeb.APIError
  alias BrainCloudWeb.APIJSON

  plug BrainCloudWeb.Plugs.RequireOwner
  plug BrainCloudWeb.Plugs.RequireScope, scope: "agents.manage"

  def create(conn, params) do
    case Agents.create_agent(params, conn.assigns.auth_context) do
      {:ok, agent} -> conn |> put_status(:created) |> json(%{agent: APIJSON.agent(agent)})
      {:error, reason} -> render_error(conn, reason)
    end
  end

  def index(conn, _params) do
    case Agents.list_agents(conn.assigns.auth_context) do
      {:ok, agents} -> json(conn, %{agents: Enum.map(agents, &APIJSON.agent/1)})
      {:error, reason} -> render_error(conn, reason)
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Agents.rename_agent(id, Map.get(params, "name"), conn.assigns.auth_context) do
      {:ok, agent} -> json(conn, %{agent: APIJSON.agent(agent)})
      {:error, reason} -> render_error(conn, reason)
    end
  end

  def delete(conn, %{"id" => id}) do
    case Agents.deactivate_agent(id, conn.assigns.auth_context) do
      {:ok, _agent} -> send_resp(conn, :no_content, "")
      {:error, reason} -> render_error(conn, reason)
    end
  end

  def reactivate(conn, %{"id" => id}) do
    case Agents.reactivate_agent(id, conn.assigns.auth_context) do
      {:ok, agent} -> json(conn, %{agent: APIJSON.agent(agent)})
      {:error, reason} -> render_error(conn, reason)
    end
  end

  defp render_error(conn, :forbidden), do: APIError.forbidden(conn)
  defp render_error(conn, :agent_not_found), do: APIError.agent_not_found(conn)

  defp render_error(conn, %Ecto.Changeset{} = changeset),
    do: APIError.validation_failed(conn, changeset)
end
