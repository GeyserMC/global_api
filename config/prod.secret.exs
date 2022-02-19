# In this file, we load production configuration and secrets
# from environment variables.
use Mix.Config

# Configure your database
config :global_api, GlobalApi.Repo,
  hostname: "ip",
  port: 3306,
  username: "username",
  password: "password",
  database: "database",
  pool_size: 50

config :global_api, :xbox_accounts_app_info,
  client_id: "client id",
  redirect_url: "https://api.geysermc.org/v2/admin/xbox/token",
  client_secret: "client secret"

config :global_api, :link_app_info,
  client_id: "client id",
  redirect_url: "https://link.geysermc.org/method/online",
  client_secret: "client secret"

config :global_api, :telemetry,
  host: "ip",
  port: 8125,
  server_id: 1

# ## Using releases (Elixir v1.9+)
#
# If you are doing OTP releases, you need to instruct Phoenix
# to start each relevant endpoint:
#
#     config :global_api, GlobalApiWeb.Endpoint, server: true
#
# Then you can assemble a release by calling `mix release`.
# See `mix help release` for more information.
