defmodule BrainCloudWeb.Plugs.ApiAuth do
  @moduledoc false

  import Plug.Conn

  alias BrainCloud.Accounts
  alias BrainCloudWeb.APIError

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> raw_token] <- get_req_header(conn, "authorization"),
         {:ok, auth_context} <- Accounts.authenticate(raw_token) do
      assign(conn, :auth_context, auth_context)
    else
      _invalid ->
        conn
        |> APIError.unauthorized()
        |> halt()
    end
  end
end
