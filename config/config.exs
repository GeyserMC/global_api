# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :global_api,
  ecto_repos: [GlobalApi.Repo]

config :sentry,
  environment_name: config_env(),
  enable_source_code_context: true,
  root_source_code_path: File.cwd!(),
  tags: %{
    env: config_env()
  },
  included_environments: [:prod]

# Configures the endpoint
config :global_api, GlobalApiWeb.Endpoint,
  ip: {0, 0, 0, 0, 0, 0, 0, 0},
  secret_key_base: "isncTcWni6IAuCWNYM9BgZXca+9KWCOGDXPafajJCvRvYS0/SHjgDdGNBZZwYPEQ",
  render_errors: [view: GlobalApiWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: GlobalApi.PubSub,
  live_view: [signing_salt: "H1cVO7Kw"]

config :esbuild,
  version: "0.14.41",
  default: [
    args:
      ~w(js/app.js js/render.js js/page/online.js --bundle --target=es2021 --outdir=../priv/static/assets/ --external:/font/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "3.1.8",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :global_api, GlobalApi.PromEx,
  manual_metrics_start_delay: :no_delay,
  drop_metrics_groups: []

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
