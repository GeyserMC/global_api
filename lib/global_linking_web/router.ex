defmodule GlobalLinkingWeb.Router do
  use GlobalLinkingWeb, :router

  pipeline :dashboard do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/xbox", GlobalLinkingWeb, log: false do
    get "/token", XboxController, :got_token
  end

  scope "/v1", GlobalLinkingWeb, log: false do
    pipe_through :api

    scope "/xbox" do
      get "/gamertag", XboxController, :get_gamertag
      get "/xuid", XboxController, :get_xuid
    end

    scope "/link" do
      get "/java", ApiController, :get_java_link
      get "/bedrock", ApiController, :get_bedrock_link
    end
  end

  # Enables LiveDashboard only for development
  if Mix.env() == :dev do
    import Phoenix.LiveDashboard.Router

    scope "/dashboard" do
      pipe_through :dashboard
      live_dashboard "/"
    end
  end
end
