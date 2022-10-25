use Mix.Config

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

# The `cipher_suite` is set to `:strong` to support only the
# latest and more secure SSL ciphers
# `log_level` is set to `:error` to ignore SSL errors received from e.g. old client

config :global_api, GlobalApiWeb.Endpoint,
  http: [port: 80],
  https: [
    dispatch: [
      {:_, [
        {"/ws", GlobalApiWeb.WebSocket, []},
        {:_, Phoenix.Endpoint.Cowboy2Handler, {GlobalApiWeb.Endpoint, []}}
      ]}
    ],
    ip: {0, 0, 0, 0, 0, 0, 0, 0},
    port: String.to_integer(System.get_env("PORT") || "443"),
    otp_app: :global_api,
    keyfile: "path/to/privkey.pem",
    cacertfile: "path/to/fullchain.pem",
    certfile: "path/to/cert.pem",
    cipher_suite: :strong,
    log_level: :error
  ],
  force_ssl: [hsts: true, host: nil, log: false],
  check_origin: [protocol <> "://*." <> domain],
  url: [host: "api." <> domain],
  static_url: [host: "cdn." <> domain],
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true,
  root: ".",
  version: Application.spec(:global_api, :vsn)

# Do not print debug messages in production
config :logger,
  level: :info,
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]

# Import the config/prod.secret.exs which loads secrets and configuration from environment variables.
import_config "prod.secret.exs"
