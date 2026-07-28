import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

config :brain_cloud_web, BrainCloudWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))],
  server: System.get_env("PHX_SERVER") in ~w(true 1)

development_auth_defaults =
  if config_env() in [:dev, :test] do
    [
      token: "development-only-token",
      actor_id: "00000000-0000-0000-0000-000000000001"
    ]
  else
    []
  end

dev_api_token =
  System.get_env("DEV_API_TOKEN") ||
    development_auth_defaults[:token] ||
    raise "environment variable DEV_API_TOKEN is missing"

dev_actor_id =
  System.get_env("DEV_ACTOR_ID") ||
    development_auth_defaults[:actor_id] ||
    raise "environment variable DEV_ACTOR_ID is missing"

if dev_api_token == "" do
  raise "environment variable DEV_API_TOKEN must not be empty"
end

case Ecto.UUID.cast(dev_actor_id) do
  {:ok, actor_id} ->
    config :brain_cloud_web, :dev_auth,
      token: dev_api_token,
      actor_id: actor_id

  :error ->
    raise "environment variable DEV_ACTOR_ID must be a UUID"
end

if config_env() == :dev do
  # Reload browser tabs when matching files change.
  config :brain_cloud_web, BrainCloudWeb.Endpoint,
    live_reload: [
      web_console_logger: true,
      patterns: [
        # Static assets, except user uploads
        ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$"E,
        # Gettext translations
        ~r"priv/gettext/.*\.po$"E,
        # Router, Controllers, LiveViews and LiveComponents
        ~r"lib/brain_cloud_web/router\.ex$"E,
        ~r"lib/brain_cloud_web/(controllers|live|components)/.*\.(ex|heex)$"E
      ]
    ]
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :brain_cloud, BrainCloud.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  config :brain_cloud_web, BrainCloudWeb.Endpoint,
    url: [
      host: System.get_env("PHX_HOST", "localhost"),
      port: String.to_integer(System.get_env("PORT", "4000")),
      scheme: "http"
    ],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :brain_cloud_web, BrainCloudWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://plug.hexdocs.pm/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :brain_cloud_web, BrainCloudWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  config :brain_cloud, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")
end
