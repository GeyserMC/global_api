import Config

protocol = "https"
domain = "geysermc.org"

config :global_api, :domain_info,
  protocol: protocol,
  api: %{
    domain: domain,
    subdomain: "api"
  },
  cdn: %{
    domain: domain,
    subdomain: "cdn"
  },
  link: %{
    domain: domain,
    subdomain: "link"
  },
  skin: %{
    domain: domain,
    subdomain: "skin"
  }

config :global_api, GlobalApiWeb.Endpoint,
  http: [
    dispatch: [
      {:_, [
        {"/ws", GlobalApiWeb.WebSocket, []},
        {:_, Phoenix.Endpoint.Cowboy2Handler, {GlobalApiWeb.Endpoint, []}}
      ]}
    ],
    ip: {0, 0, 0, 0, 0, 0, 0, 0},
    port: String.to_integer(System.get_env("PORT") || "80"),
    otp_app: :global_api
  ],
  force_ssl: [rewrite_on: [:x_forwarded_proto, :x_forwarded_host], host: nil, log: false],
  check_origin: [protocol <> "://*." <> domain],
  url: [host: "api." <> domain],
  static_url: [host: "cdn." <> domain],
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true,
  version: Application.spec(:global_api, :vsn)

# Do not print debug messages in production
config :logger, level: :info
