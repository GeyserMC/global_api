defmodule GlobalApiWeb.Endpoint do
  use Sentry.PlugCapture
  use Phoenix.Endpoint, otp_app: :global_api

  @static_url Application.get_env(:global_api, GlobalApiWeb.Endpoint)[:static_url][:host]

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

    plug Phoenix.LiveDashboard.RequestLogger,
         param_key: "request_logger",
         cookie_key: "request_logger"

    plug Plug.RequestId

    plug Plug.Session, @session_options
  end

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.CodeReloader
    plug Phoenix.LiveReloader
  end

  if Mix.env() == :prod do
    plug Plug.SSL
  end

  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint], log: Mix.env() != :prod

  # only serve the assets at the cdn subdomain
  plug :static_assets, nil

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

  @static_opts Plug.Static.init(at: "/", from: :global_api, gzip: true, headers: %{"access-control-allow-origin" => "*"})

  def static_assets(conn, _) do
    if @static_url == conn.host, do: Plug.Static.call(conn, @static_opts), else: conn
  end
end
