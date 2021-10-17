defmodule GlobalApiWeb.Endpoint do
  use Sentry.PlugCapture
  use Phoenix.Endpoint, otp_app: :global_api

  # Live Dashboard and live code reload is only enabled during development
  if Mix.env() == :dev do
    # The session will be stored in the cookie and signed,
    # this means its contents can be read but not tampered with.
    # Set :encryption_salt if you would also like to encrypt it.
    @session_options [
      store: :cookie,
      key: "_global_api_key",
      signing_salt: "jvggC7w3"
    ]

    socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

    # Doesn't work because I removed PubSub
#    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
#    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader

    plug Phoenix.LiveDashboard.RequestLogger,
         param_key: "request_logger",
         cookie_key: "request_logger"

    plug Plug.RequestId

    plug Plug.Session, @session_options
  end

  plug Unplug,
       if: {GlobalApi.UnplugPredicates.SecureMetricsEndpoint, []},
       do: {PromEx.Plug, prom_ex_module: GlobalApi.PromEx}

  if Mix.env() == :prod do
    plug Plug.SSL
  end

  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint], log: Mix.env() != :prod

  # only serve the assets at the link subdomain when running prod
  plug :static_assets, Mix.env() == :prod

  # stuff from let's encrypt
  plug Plug.Static,
       at: "/",
       from: :global_api,
       only: ~w(.well-known)

  plug Plug.Parsers,
       parsers: [:multipart, :json],
       pass: ["*/*"],
       json_decoder: Phoenix.json_library()
  plug Sentry.PlugContext

  plug CORSPlug

  plug GlobalApiWeb.Router

  @static_opts Plug.Static.init(at: "/", from: Application.get_env(:global_api, :static_assets), gzip: true)

  def static_assets(conn, is_prod) do
    if String.starts_with?(conn.host, "cdn.") do
        Plug.Static.call(conn, @static_opts)
    else
      conn
    end
  end
end
