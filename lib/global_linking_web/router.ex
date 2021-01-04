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

  scope "/api/link", GlobalLinkingWeb do
    pipe_through :api

    get "/java/", ApiController, :get_java_link
    get "/bedrock/", ApiController, :get_bedrock_link
  end

  # Other scopes may use custom stacks.
  # scope "/api", GlobalLinkingWeb do
  #   pipe_through :api
  # end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env()== :dev do
    import Phoenix.LiveDashboard.Router

    scope "/dashboard" do
      pipe_through :dashboard
      live_dashboard "/"
    end
  end
end
