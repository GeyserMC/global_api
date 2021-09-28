defmodule GlobalApiWeb.Router do
  use GlobalApiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :browser do
    plug :accepts, ["html"]
  end

  # only allow the skin subdomain when running in prod
  skin_opts = if Mix.env() == :dev do [] else [host: "skin."] end
  scope "/", skin_opts do
    pipe_through :browser

    get "/", GlobalApiWeb.Skin.SkinsController, :index

    #todo reserve the cdn subdomain
    get "/preview", GlobalApiWeb.Cdn.PreviewController, :preview
  end

  # only allow the link subdomain when running in prod
  link_opts = if Mix.env() == :dev do [] else [host: "link."] end
  scope "/", GlobalApiWeb.Link, link_opts do
    pipe_through :browser

    get "/", LinkingController, :index
    get "/start", LinkingController, :start

    scope "/link" do
      get "/online", LinkingController, :online
      get "/server", LinkingController, :server
    end
  end

  # only allow the api subdomain when running in prod
  api_opts = if Mix.env() == :dev do [] else [host: "api."] end

  scope "/", api_opts do
    scope "/v1", GlobalApiWeb.Api, log: Mix.env() == :dev do
      pipe_through :api

      scope "/link" do
        get "/bedrock/:xuid", LinkController, :get_bedrock_link
        get "/java/:uuid", LinkController, :get_java_link
        post "/online", LinkController, :verify_online_link
      end

      scope "/news" do
        get "/", NewsController, :get_news
      end

      scope "/skin" do
        get "/:xuid", SkinController, :get_skin
      end

      scope "/stats" do
        get "/", StatsController, :get_all_stats
      end

      scope "/utils" do
        get "/uuid/bedrock_or_java/:username", UtilsController, :get_bedrock_or_java_uuid
      end

      scope "/xbox" do
        get "/gamertag/:xuid", XboxController, :get_gamertag
        get "/xuid/:gamertag", XboxController, :get_xuid
      end
    end

    scope "/v2", GlobalApiWeb.Api, log: Mix.env() == :dev do
      pipe_through :api

      scope "/admin" do
        scope "/xbox" do
          get "/token", XboxController, :got_token
        end
      end

      scope "/skin" do
        get "/recent_uploads", SkinController, :get_recent_uploads
      end

      scope "/xbox" do
        scope "/batch" do
          post "/gamertag", XboxController, :get_gamertag_batch
        end
      end
    end

    get "/health", GlobalApiWeb.Api.HealthController, :health
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
end
