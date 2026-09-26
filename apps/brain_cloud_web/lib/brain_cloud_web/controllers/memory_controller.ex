defmodule BrainCloudWeb.MemoryController do
  use BrainCloudWeb, :controller

  alias BrainCloud.Memories
  alias BrainCloud.Projects
  alias BrainCloudWeb.APIError
  alias BrainCloudWeb.APIJSON
  alias BrainCloudWeb.MemoryCursor

  plug BrainCloudWeb.Plugs.RequireScope, [scope: "memory.write"] when action in [:create]
  plug BrainCloudWeb.Plugs.RequireScope, [scope: "memory.read"] when action in [:index, :show]

  def index(conn, %{"project_id" => project_id} = params) do
    case Projects.authorize_project(project_id, conn.assigns.auth_context, :reader) do
      {:ok, project} -> list_authorized_memories(conn, project, params)
      {:error, :project_not_found} -> APIError.project_not_found(conn)
    end
  end

  def create(conn, %{"project_id" => project_id} = params) do
    case Memories.create_memory(project_id, params, conn.assigns.auth_context) do
      {:ok, memory} ->
        conn
        |> put_status(:created)
        |> json(%{memory: APIJSON.memory(memory)})

      {:error, :project_not_found} ->
        APIError.project_not_found(conn)

      {:error, :forbidden} ->
        APIError.forbidden(conn)

      {:error, changeset} ->
        APIError.validation_failed(conn, changeset)
    end
  end

  def show(conn, %{"project_id" => project_id, "id" => memory_id}) do
    case Memories.get_memory(project_id, memory_id, conn.assigns.auth_context) do
      {:ok, memory} ->
        json(conn, %{memory: APIJSON.memory(memory)})

      {:error, :project_not_found} ->
        APIError.project_not_found(conn)

      {:error, :memory_not_found} ->
        APIError.memory_not_found(conn)
    end
  end

  defp list_authorized_memories(conn, project, params) do
    case {parse_limit(params), parse_cursor(params)} do
      {{:ok, limit}, {:ok, cursor}} ->
        {memories, has_more?} = Memories.list_memories(project, limit, cursor)
        next_cursor = if has_more?, do: MemoryCursor.encode(List.last(memories)), else: nil

        conn
        |> put_resp_header("cache-control", "no-store")
        |> json(%{
          memories: Enum.map(memories, &APIJSON.memory_summary/1),
          next_cursor: next_cursor
        })

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
        case MemoryCursor.decode(value) do
          {:ok, cursor} -> {:ok, cursor}
          {:error, :invalid_cursor} -> {:error, %{cursor: ["is invalid"]}}
        end

      {:ok, _value} ->
        {:error, %{cursor: ["is invalid"]}}
    end
  end
end
