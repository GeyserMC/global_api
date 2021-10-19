defmodule GlobalApiWeb.Link.LinkingController do
  @moduledoc false
  use GlobalApiWeb, :controller

  # used for previews
  def preview_info(page) do
    case page do
      :index -> {:link, "Global Linking"}
      :start -> {:link, "Start Global Linking"}
      :online -> {:link, "Online linking"}
      :server -> {:link, "Server linking"}
      _ -> nil
    end
  end

  def index(conn, _) do
    render(
      conn,
      "index.html",
      page_title: "Global Linking",
      page_description: "Link once, join on every server with Global Linking enabled",
      page_preview_image: true,
      render_navbar: false
    )
  end

  def start(conn, _) do
    render(
      conn,
      "start.html",
      page_title: "Start - Global Linking",
      page_description: "Let's start linking. Link once, join on every server with Global Linking enabled",
      page_preview_image: true,
      render_navbar: false
    )
  end

  def online(conn, _) do
    render(
      conn,
      "online.html",
      page_title: "Online linking - Global Linking",
      page_description: "Link your Bedrock and Java accounts online",
      page_preview_image: true,
      render_navbar: false
    )
  end

  def server(conn, _) do
    render(
      conn,
      "server.html",
      page_title: "Server linking - Global Linking",
      page_description: "Link your Bedrock and Java accounts online",
      page_preview_image: true,
      render_navbar: false
    )
  end
end
