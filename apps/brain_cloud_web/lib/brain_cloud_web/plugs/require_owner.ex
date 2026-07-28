defmodule BrainCloudWeb.Plugs.RequireOwner do
  @moduledoc false

  import Plug.Conn

  alias BrainCloudWeb.APIError

  def init(opts), do: opts

  def call(%Plug.Conn{assigns: %{auth_context: %{role: "owner"}}} = conn, _opts), do: conn

  def call(conn, _opts) do
    conn
    |> APIError.forbidden()
    |> halt()
  end
end
