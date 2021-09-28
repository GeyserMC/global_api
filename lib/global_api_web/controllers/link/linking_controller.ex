defmodule GlobalApiWeb.Link.LinkingController do
  @moduledoc false
  use GlobalApiWeb, :controller

  def index(conn, _) do
    render(
      conn,
      "index.html",
      page_title: "Global Linking",
      page_description: "Link once, join on every server with Global Linking enabled",
      page_host: "https://link.geysermc.org",
      page_image: "link/index",
      render_navbar: false
    )
  end

  def start(conn, _) do
    render(
      conn,
      "start.html",
      page_title: "Start - Global Linking",
      page_description: "Let's start linking. Link once, join on every server with Global Linking enabled",
      page_host: "https://link.geysermc.org",
      page_image: "link/start",
      render_navbar: false
    )
  end

  def online(conn, _) do
    render(
      conn,
      "online.html",
      page_title: "Online linking - Global Linking",
      page_description: "Link your Bedrock and Java accounts online",
      page_host: "https://link.geysermc.org",
      page_image: "link/online",
      render_navbar: false
    )
  end

  def server(conn, _) do
    render(
      conn,
      "server.html",
      page_title: "Server linking - Global Linking",
      page_description: "Link your Bedrock and Java accounts online",
      page_host: "https://link.geysermc.org",
      page_image: "link/server",
      render_navbar: false
    )
  end
end
