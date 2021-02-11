# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configures the endpoint
config :global_linking, GlobalLinkingWeb.Endpoint,
  url: [host: "localhost"],
  http: [
    dispatch: [
           {:_, [
             {"/ws", GlobalLinkingWeb.WebSocket, []},
             {:_, Phoenix.Endpoint.Cowboy2Handler, {GlobalLinkingWeb.Endpoint, []}}
           ]}
    ],
    port: String.to_integer(System.get_env("PORT") || if Mix.env() == :dev do "4000" else "80" end),
    transport_options: [socket_opts: [:inet]]
  ],
  secret_key_base: "isncTcWni6IAuCWNYM9BgZXca+9KWCOGDXPafajJCvRvYS0/SHjgDdGNBZZwYPEQ",
  render_errors: [view: GlobalLinkingWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: GlobalLinking.PubSub,
  live_view: [signing_salt: "H1cVO7Kw"]

# it currently only supports a message that has been created already by the webhook
config :global_linking, :webhook,
  url: "https://discord.com/api/webhooks/{webhook.id}/{webhook.token}/messages/{message.id}"

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
