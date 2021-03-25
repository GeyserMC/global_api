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
  metrics_auth: "your_cool_metrics auth"

# Configure your database
config :global_api, GlobalApi.Repo,
       hostname: "hostname",
       username: "username",
       password: "password",
       database: "global_api",
       pool_size: 2

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
         host: "example.org:3000",
         auth_token: "a_cool_and_nice_token"
       ],
       metrics_server: :disabled

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
