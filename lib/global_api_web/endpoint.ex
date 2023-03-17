defmodule GlobalApiWeb.Endpoint do
  use Sentry.PlugCapture
  use Phoenix.Endpoint, otp_app: :global_api

  alias GlobalApiWeb.Router
  alias GlobalApi.Utils

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: Router.session_options()]]

  # Live Dashboard and is only enabled during development
  if Utils.environment() == :dev do
    plug Phoenix.LiveDashboard.RequestLogger,
         param_key: "request_logger",
         cookie_key: "request_logger"
  end

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.CodeReloader
    plug Phoenix.LiveReloader
  end

  # plug Unplug,
  #      if: {GlobalApi.UnplugPredicates.SecureMetricsEndpoint, []},
  #      do: {PromEx.Plug, prom_ex_module: GlobalApi.PromEx}

  if Utils.environment() == :prod do
    plug Plug.SSL
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  # only serve the assets at the cdn subdomain
  plug :static_assets, nil

  # .well-known is needed for let's encrypt
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
    if Utils.get_env(:app, :static_url) == conn.host, do: Plug.Static.call(conn, @static_opts), else: conn
  end
end
