# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

# Configure Mix tasks and generators
config :brain_cloud,
  ecto_repos: [BrainCloud.Repo]

config :brain_cloud_web,
  ecto_repos: [BrainCloud.Repo],
  generators: [context_app: :brain_cloud, binary_id: true]

# Configures the endpoint
config :brain_cloud_web, BrainCloudWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: BrainCloudWeb.ErrorHTML, json: BrainCloudWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: BrainCloud.PubSub,
  live_view: [signing_salt: "XeiGlkwf"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  brain_cloud_web: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../apps/brain_cloud_web/assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.3.0",
  brain_cloud_web: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("../apps/brain_cloud_web", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :logger_json, encoder: JSON

# Use Jason for JSON parsing in Phoenix
config :phoenix,
  json_library: Jason,
  filter_parameters: ["authorization", "secret", "token"]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

# Configure LiveView
config :phoenix_live_view,
  # the attribute set on all root tags. Used for Phoenix.LiveView.ColocatedCSS.
  root_tag_attribute: "phx-r"
