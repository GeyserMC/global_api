import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

#TODO: place all the domain_info stuff in here and use FastGlobal
#todo only use environment variables in here

is_prod = config_env() == :prod

pool_size = if is_prod do 50 else 3 end

# the defaults for when docker compose is used
config :global_api, GlobalApi.Repo,
  hostname: "host.docker.internal",
  port: 3306,
  username: "root",
  password: "global_api",
  database: "global_api_#{config_env()}",
  pool_size: pool_size,
  database_timeout: 25_000

config :global_api, :app,
  environment: config_env(),
  static_url: "cdn.geysermc",
  well_known_dir: "../.well-known",
  metrics_auth: "your metrics auth",
  mineskin_api_key: "your mineskin api key"

config :sentry,
  dsn: "your sentry dsn"

config :global_api, :xbox_accounts_app_info,
  client_id: "client id",
  redirect_url: "https://api.geysermc.org/v2/admin/xbox/token",
  client_secret: "client secret"

config :global_api, :link_app_info,
  client_id: "client id",
  redirect_url: "https://link.geysermc.org/method/online",
  client_secret: "client secret"

config :global_api, :telemetry,
  # enter ip/hostname if you want to enable it
  host: nil,
  port: 8125,
  server_id: 1

config :global_api, GlobalApi.PromEx,
  grafana: :disabled,
  metrics_server: :disabled

if is_prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  config :global_api, GlobalApiWeb.Endpoint,
    secret_key_base: secret_key_base
end
