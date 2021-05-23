defmodule GlobalApiWeb.Router do
  use GlobalApiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  # only allow the link subdomain when running in prod
  link_opts = if Mix.env() == :dev do [] else [host: "link."] end
  scope "/", link_opts do
    get "/", GlobalApiWeb.RootController, :get_index
  end

  # only allow the api subdomain when running in prod
  api_opts = if Mix.env() == :dev do [] else [host: "api."] end

  scope "/", api_opts do
    scope "/v1", GlobalApiWeb, log: Mix.env() == :dev do
      pipe_through :api

      scope "/link" do
        get "/bedrock/:xuid", LinkController, :get_bedrock_link
        get "/java/:uuid", LinkController, :get_java_link
        post "/online", LinkController, :verify_online_link
      end

      scope "/skin" do
        get "/:xuid", SkinController, :get_skin
      end

      scope "/xbox" do
        get "/gamertag/:xuid", XboxController, :get_gamertag
        get "/xuid/:gamertag", XboxController, :get_xuid
      end
    end

    scope "/xbox", GlobalApiWeb, log: Mix.env() == :dev do
      pipe_through :api

      get "/token", XboxController, :got_token
    end

    get "/health", GlobalApiWeb.HealthController, :health
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
