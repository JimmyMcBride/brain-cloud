import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
database_config =
  case System.get_env("DATABASE_URL") do
    nil ->
      [
        username: "brain",
        password: "brain",
        hostname: "localhost",
        database: "brain_cloud_test#{System.get_env("MIX_TEST_PARTITION")}"
      ]

    url ->
      [url: url]
  end

pool_config =
  if System.get_env("PHASE2_UPGRADE") == "true" do
    []
  else
    [pool: Ecto.Adapters.SQL.Sandbox]
  end

config :brain_cloud,
       BrainCloud.Repo,
       Keyword.merge(
         database_config,
         pool_config ++ [pool_size: System.schedulers_online() * 2]
       )

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :brain_cloud_web, BrainCloudWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "Q8VTo2ufeI0Snn8KjipaKiWThoprj5KaPCzFtNj+9L/a53NsZv62mEkmX6d3zsQQ",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
