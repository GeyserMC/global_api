defmodule GlobalLinkingWeb.Router do
  use GlobalLinkingWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/v1", GlobalLinkingWeb, log: false do
    pipe_through :api

    scope "/link" do
      get "/bedrock", LinkController, :get_bedrock_link
      get "/java", LinkController, :get_java_link
    end

    scope "/skin" do
      get "/", SkinController, :get_skin
    end

    scope "/xbox" do
      get "/gamertag", XboxController, :get_gamertag
      get "/xuid", XboxController, :get_xuid
    end
  end

  scope "/xbox", GlobalLinkingWeb, log: false do
    pipe_through :api

    get "/token", XboxController, :got_token
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
