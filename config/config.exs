# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :global_api,
  ecto_repos: [GlobalApi.Repo]

config :global_api, :app,
  metrics_auth: "your metrics auth",
  mineskin_api_key: "your mineskin api key"

config :sentry,
  dsn: "your sentry dsn",
  environment_name: Mix.env,
  enable_source_code_context: true,
  root_source_code_path: File.cwd!(),
  tags: %{
    env: Mix.env
  },
  included_environments: [:prod]

# Configures the endpoint
config :global_api, GlobalApiWeb.Endpoint,
  ip: {0, 0, 0, 0, 0, 0, 0, 0},
  secret_key_base: "isncTcWni6IAuCWNYM9BgZXca+9KWCOGDXPafajJCvRvYS0/SHjgDdGNBZZwYPEQ",
  render_errors: [view: GlobalApiWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: GlobalApi.PubSub,
  live_view: [signing_salt: "H1cVO7Kw"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :global_api, GlobalApi.PromEx,
  manual_metrics_start_delay: :no_delay,
  drop_metrics_groups: [],
  grafana: [
   host: "your grafana ip",
   auth_token: "your grafana auth token"
  ],
  metrics_server: :disabled

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
