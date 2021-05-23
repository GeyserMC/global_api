defmodule GlobalApiWeb.Endpoint do
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

    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader

    plug Phoenix.LiveDashboard.RequestLogger,
         param_key: "request_logger",
         cookie_key: "request_logger"

    plug Plug.RequestId

    plug Plug.Session, @session_options
  end

  plug Plug.Parsers,
    parsers: [:multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Unplug,
       if: {GlobalApi.UnplugPredicates.SecureMetricsEndpoint, []},
       do: {PromEx.Plug, prom_ex_module: GlobalApi.PromEx}

  if Mix.env() == :prod do
    plug Plug.SSL
  end

  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]
  
  plug CORSPlug

  # only serve the assets at the link subdomain when running prod
  plug :static_assets, Mix.env() == :prod

  plug GlobalApiWeb.Router

  @static_opts Plug.Static.init(at: "/", from: :global_api, gzip: false)

  def static_assets(conn, is_prod) do
    if (is_prod && String.starts_with?(conn.host, "link.")) || !is_prod do
        Plug.Static.call(conn, @static_opts)
    else
      conn
    end
  end
end
