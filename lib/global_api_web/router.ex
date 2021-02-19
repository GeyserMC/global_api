defmodule GlobalApiWeb.Router do
  use GlobalApiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/v1", GlobalApiWeb, log: false do
    pipe_through :api

    scope "/link" do
      get "/bedrock/:xuid", LinkController, :get_bedrock_link
      get "/java/:uuid", LinkController, :get_java_link
    end

    scope "/skin" do
      get "/:xuid", SkinController, :get_skin
    end

    scope "/xbox" do
      get "/gamertag/:xuid", XboxController, :get_gamertag
      get "/xuid/:gamertag", XboxController, :get_xuid
    end
  end

  scope "/xbox", GlobalApiWeb, log: false do
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
