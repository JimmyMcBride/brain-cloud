defmodule BrainCloudWeb.Plugs.RequireScope do
  @moduledoc false

  import Plug.Conn

  alias BrainCloud.Accounts
  alias BrainCloudWeb.APIError

  def init(opts), do: Keyword.fetch!(opts, :scope)

  def call(conn, scope) do
    if Accounts.authorized?(conn.assigns.auth_context, scope) do
      conn
    else
      conn
      |> APIError.forbidden()
      |> halt()
    end
  end
end
