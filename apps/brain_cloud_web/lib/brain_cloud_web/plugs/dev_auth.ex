defmodule BrainCloudWeb.Plugs.DevAuth do
  @moduledoc """
  Authenticates Phase 1 product routes with one development bearer token.
  """

  import Plug.Conn

  alias BrainCloudWeb.APIError

  def init(opts), do: opts

  def call(conn, _opts) do
    auth = Application.fetch_env!(:brain_cloud_web, :dev_auth)

    case get_req_header(conn, "authorization") do
      ["Bearer " <> provided_token] ->
        authenticate(conn, provided_token, auth)

      _headers ->
        reject(conn)
    end
  end

  defp authenticate(conn, provided_token, auth) do
    expected_token = Keyword.fetch!(auth, :token)

    provided_digest = :crypto.hash(:sha256, provided_token)
    expected_digest = :crypto.hash(:sha256, expected_token)

    if Plug.Crypto.secure_compare(provided_digest, expected_digest) do
      assign(conn, :actor_id, Keyword.fetch!(auth, :actor_id))
    else
      reject(conn)
    end
  end

  defp reject(conn) do
    conn
    |> APIError.unauthorized()
    |> halt()
  end
end
