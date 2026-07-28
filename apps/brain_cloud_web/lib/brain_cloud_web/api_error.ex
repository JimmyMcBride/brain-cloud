defmodule BrainCloudWeb.APIError do
  @moduledoc false

  import Phoenix.Controller, only: [json: 2]
  import Plug.Conn

  def unauthorized(conn) do
    render(conn, :unauthorized, "unauthorized", "Authentication required")
  end

  def project_not_found(conn) do
    render(conn, :not_found, "project_not_found", "Project not found")
  end

  def memory_not_found(conn) do
    render(conn, :not_found, "memory_not_found", "Memory not found")
  end

  def validation_failed(conn, %Ecto.Changeset{} = changeset) do
    validation_failed(conn, changeset_details(changeset))
  end

  def validation_failed(conn, details) when is_map(details) do
    render(
      conn,
      :unprocessable_entity,
      "validation_failed",
      "Request validation failed",
      details
    )
  end

  defp render(conn, status, code, message, details \\ %{}) do
    conn
    |> put_status(status)
    |> json(%{
      error: %{
        code: code,
        message: message,
        details: details
      }
    })
  end

  defp changeset_details(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
