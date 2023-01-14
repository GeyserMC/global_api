defmodule GlobalApiWeb.Router do
  use GlobalApiWeb, :router
  use Plug.ErrorHandler

  alias GlobalApi.Utils

  domain_info = Application.compile_env(:global_api, :domain_info)
  # we apparently can't call functions
  api_host = domain_info[:api][:subdomain] <> "."
  cdn_host = domain_info[:cdn][:subdomain] <> "."
  link_host = domain_info[:link][:subdomain] <> "."
  skin_host = domain_info[:skin][:subdomain] <> "."

  @json_subdomains ["api.", "cdn."]

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_global_api_key",
    signing_salt: "jvggC7w3"
  ]
  def session_options, do: @session_options


  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :swagger do
    plug OpenApiSpex.Plug.PutApiSpec, module: GlobalApiWeb.ApiSpec
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug Plug.Session, @session_options
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {GlobalApiWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", GlobalApiWeb.Cdn, host: cdn_host do
    pipe_through :api

    scope "/render" do
      get "/front/:texture_id", RenderController, :front
      get "/raw/:texture_id", RenderController, :raw
    end
  end

  scope "/", GlobalApiWeb.Skin, host: skin_host do
    pipe_through :browser

    get "/", SkinsController, :index

    scope "/recent" do
      live "/bedrock", RecentBedrock
    end

    scope "/popular" do
      live "/bedrock", PopularBedrock
    end

    scope "/skin" do
      live "/:id", SkinInfo
      # get "/:texture_id", ItemInfoController, :skin_info
    end

    scope "/cape" do
      # get "/:texture_id", ItemInfoController, :cape_info
    end

    scope "/profile" do
      live "/:id", ProfileInfo
    end
  end

  scope "/", GlobalApiWeb.Link, host: link_host do
    pipe_through :browser

    get "/", LinkingController, :index
    get "/start", LinkingController, :start

    scope "/method" do
      get "/online", LinkingController, :online
      get "/server", LinkingController, :server
    end
  end

  scope "/", host: api_host do
    scope "/v1", GlobalApiWeb.Api, log: Utils.environment() == :dev do
      pipe_through :api

      scope "/link" do
        get "/bedrock/:xuid", LinkController, :get_bedrock_link_v1
        get "/java/:uuid", LinkController, :get_java_link_v1
      end

      scope "/news" do
        get "/", NewsController, :get_news
      end

      scope "/stats" do
        get "/", StatsController, :get_all_stats
      end

      scope "/xbox" do
        get "/gamertag/:xuid", XboxController, :get_gamertag_v1
        get "/xuid/:gamertag", XboxController, :get_xuid_v1
      end
    end

    scope "/v2", GlobalApiWeb.Api, log: Utils.environment() == :dev do
      pipe_through :api

      scope "/admin" do
        scope "/xbox" do
          get "/token", XboxController, :got_token
        end
      end

      scope "/link" do
        get "/bedrock/:xuid", LinkController, :get_bedrock_link_v2
        get "/java/:uuid", LinkController, :get_java_link_v2
        post "/online", LinkController, :verify_online_link
      end

      scope "/news" do
        get "/:project", NewsController, :get_project_news
      end

      scope "/skin" do
        scope "/bedrock" do
          get "/recent", SkinController, :get_recent_uploads
        end
        get "/:xuid", SkinController, :get_skin
      end

      scope "/stats" do
        get "/", StatsController, :get_all_stats
      end

      scope "/utils" do
        get "/uuid/bedrock_or_java/:username", UtilsController, :get_bedrock_or_java_uuid
      end

      scope "/versions" do
        get "/:project", VersionsController, :project_version
      end

      scope "/xbox" do
        scope "/batch" do
          post "/gamertag", XboxController, :get_gamertag_batch
        end
        get "/gamertag/:xuid", XboxController, :get_gamertag_v2
        get "/xuid/:gamertag", XboxController, :get_xuid_v2
      end
    end

    get "/health", GlobalApiWeb.Api.HealthController, :health

    # swagger (open api) related stuff
    scope "/" do
      scope "/openapi" do
        pipe_through [:api, :swagger]
        get "/", OpenApiSpex.Plug.RenderSpec, []
      end
      scope "/docs" do
        pipe_through :browser
        get "/", OpenApiSpex.Plug.SwaggerUI, path: "/openapi"
      end
    end
  end

  # Enables LiveDashboard only for development
  if Utils.environment() == :dev do
    import Phoenix.LiveDashboard.Router

    pipeline :dashboard do
      plug :accepts, ["html"]
      plug :fetch_session
      plug :fetch_flash
      plug :protect_from_forgery
      plug :put_secure_browser_headers
    end

    scope "/dashboard" do
      pipe_through :dashboard
      live_dashboard "/"
    end
  end

  def handle_errors(conn, %{reason: %GlobalApiWeb.WrappedError{message: message, status_code: status_code}}) do
    handle_error(conn, status_code, message)
  end

  def handle_errors(conn, _) do
    handle_error(conn, conn.status, Plug.Conn.Status.reason_phrase(conn.status))
  end

  defp handle_error(conn, status_code, message) do
    if String.starts_with?(conn.host, @json_subdomains) do
      handle_json_error(conn, status_code, message)
    else
      handle_html_error(conn, status_code, message)
    end
  end

  defp handle_json_error(conn, status_code, message) do
    conn
    |> put_status(status_code)
    |> json(%{message: message})
    |> halt()
  end

  defp handle_html_error(conn, status_code, message) do
    conn
    |> put_view(GlobalApiWeb.ErrorView)
    |> put_layout({GlobalApiWeb.LayoutView, "app.html"})
    |> render(
      "error.html",
      page_title: status_code,
      page_description: message
    )
  end

  def cdn_host do
    domain_info = Application.get_env(:global_api, :domain_info)
    domain_info[:protocol] <> "://" <> domain_info[:cdn][:subdomain] <> "." <> domain_info[:cdn][:domain]
  end
end
