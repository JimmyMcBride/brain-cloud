defmodule BrainCloudWeb.ProjectController do
  use BrainCloudWeb, :controller

  alias BrainCloud.Projects
  alias BrainCloudWeb.APIError
  alias BrainCloudWeb.APIJSON
  alias BrainCloudWeb.ProjectCursor

  plug BrainCloudWeb.Plugs.RequireScope, [scope: "projects.create"] when action in [:create]
  plug BrainCloudWeb.Plugs.RequireScope, [scope: "projects.read"] when action in [:index, :show]

  def index(conn, params) do
    case {parse_limit(params), parse_cursor(params)} do
      {{:ok, limit}, {:ok, cursor}} ->
        {projects, has_more?} = Projects.list_projects(conn.assigns.auth_context, limit, cursor)
        next_cursor = if has_more?, do: ProjectCursor.encode(List.last(projects)), else: nil

        conn
        |> put_resp_header("cache-control", "no-store")
        |> json(%{projects: Enum.map(projects, &APIJSON.project/1), next_cursor: next_cursor})

      {limit_result, cursor_result} ->
        details =
          [limit_result, cursor_result]
          |> Enum.flat_map(fn
            {:error, details} -> Map.to_list(details)
            {:ok, _value} -> []
          end)
          |> Map.new()

        APIError.validation_failed(conn, details)
    end
  end

  def show(conn, %{"id" => id}) do
    case Projects.authorize_project(id, conn.assigns.auth_context, :reader) do
      {:ok, project} ->
        conn
        |> put_resp_header("cache-control", "no-store")
        |> json(%{project: APIJSON.project(project)})

      {:error, :project_not_found} ->
        APIError.project_not_found(conn)
    end
  end

  def create(conn, params) do
    case Projects.create_project(params, conn.assigns.auth_context) do
      {:ok, project} ->
        conn
        |> put_status(:created)
        |> json(%{project: APIJSON.project(project)})

      {:error, changeset} ->
        APIError.validation_failed(conn, changeset)
    end
  end

  defp parse_limit(params) do
    case Map.fetch(params, "limit") do
      :error -> {:ok, 20}
      {:ok, value} when is_binary(value) -> parse_limit_value(value)
      {:ok, _value} -> {:error, %{limit: ["must be an integer between 1 and 100"]}}
    end
  end

  defp parse_limit_value(value) do
    case Integer.parse(value) do
      {limit, ""} when limit in 1..100 -> {:ok, limit}
      _invalid -> {:error, %{limit: ["must be an integer between 1 and 100"]}}
    end
  end

  defp parse_cursor(params) do
    case Map.fetch(params, "cursor") do
      :error ->
        {:ok, nil}

      {:ok, value} when is_binary(value) ->
        case ProjectCursor.decode(value) do
          {:ok, cursor} -> {:ok, cursor}
          {:error, :invalid_cursor} -> {:error, %{cursor: ["is invalid"]}}
        end

      {:ok, _value} ->
        {:error, %{cursor: ["is invalid"]}}
    end
  end
end
