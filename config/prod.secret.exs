# In this file, we load production configuration and secrets
# from environment variables. You can also hardcode secrets,
# although such is generally not recommended and you have to
# remember to add this file to your .gitignore.
use Mix.Config

# Configure your database
config :global_api, :app,
  hostname: "localhost",
  username: "global_api",
  password: "some_pass",
  database: "global_api_dev",
  pool_size: 10

config :global_api, :app_info,
  client_id: "client id",
  redirect_url: "https://api.geysermc.org/xbox/token",
  client_secret: "client secret"

# ## Using releases (Elixir v1.9+)
#
# If you are doing OTP releases, you need to instruct Phoenix
# to start each relevant endpoint:
#
#     config :global_api, GlobalApiWeb.Endpoint, server: true
#
# Then you can assemble a release by calling `mix release`.
# See `mix help release` for more information.
