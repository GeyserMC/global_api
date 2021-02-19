# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configures the endpoint
config :global_api, GlobalApiWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "isncTcWni6IAuCWNYM9BgZXca+9KWCOGDXPafajJCvRvYS0/SHjgDdGNBZZwYPEQ",
  render_errors: [view: GlobalApiWeb.ErrorView, accepts: ~w(json), layout: false],
  live_view: [signing_salt: "H1cVO7Kw"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
