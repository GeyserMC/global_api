defmodule GlobalApiWeb.Router do
  use GlobalApiWeb, :router
  use Plug.ErrorHandler

  domain_info = Application.get_env(:global_api, :domain_info)
  # we apparently can't call functions
  api_host = domain_info[:api][:subdomain] <> "."
  cdn_host = domain_info[:cdn][:subdomain] <> "."
  link_host = domain_info[:link][:subdomain] <> "."
  skin_host = domain_info[:skin][:subdomain] <> "."

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :swagger do
    plug OpenApiSpex.Plug.PutApiSpec, module: GlobalApiWeb.ApiSpec
  end

  pipeline :browser do
    plug :accepts, ["html"]
  end

  scope "/", host: cdn_host do
    pipe_through :api
  end

  scope "/", GlobalApiWeb.Skin, host: skin_host do
    pipe_through :browser

    get "/", SkinsController, :index

    scope "/recent" do
      get "/bedrock", SkinsController, :recent_bedrock
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
    scope "/v1", GlobalApiWeb.Api, log: Mix.env() == :dev do
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

    scope "/v2", GlobalApiWeb.Api, log: Mix.env() == :dev do
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
        get "/recent_uploads", SkinController, :get_recent_uploads
        get "/:xuid", SkinController, :get_skin
      end

      scope "/stats" do
        get "/", StatsController, :get_all_stats
      end

      scope "/utils" do
        get "/uuid/bedrock_or_java/:username", UtilsController, :get_bedrock_or_java_uuid
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
      scope "/swaggerui" do
        pipe_through :browser
        get "/", OpenApiSpex.Plug.SwaggerUI, path: "/openapi"
      end
    end
  end

  # Enables LiveDashboard only for development
  if Mix.env() == :dev do
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

  #todo expand this to include other errors as well
  defp handle_errors(conn, %{reason: %Phoenix.Router.NoRouteError{}}) do
    if String.starts_with?(conn.host, "api.") do
      handle_errors(conn, nil) # pass it through to the function below
    else
      conn
      |> put_view(GlobalApiWeb.ErrorView)
      |> put_layout({GlobalApiWeb.LayoutView, "app.html"})
      |> render(
        "error.html",
        page_title: conn.status,
        page_description: Plug.Conn.Status.reason_phrase(conn.status)
      )
    end
  end

  defp handle_errors(conn, _) do
    conn
    |> json(%{message: "#{conn.status} #{Plug.Conn.Status.reason_phrase(conn.status)}"})
    |> halt()
  end
end
