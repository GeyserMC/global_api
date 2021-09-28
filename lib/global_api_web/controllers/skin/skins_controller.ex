defmodule GlobalApiWeb.Skin.SkinsController do
  @moduledoc false
  use GlobalApiWeb, :controller

  def index(conn, _) do
    render(conn, "index.html", page_title: "test", page_description: "uwu", page_host: "https://skins.geysermc.org")
  end

  def preview(conn, %{"page" => page}) do
    # todo store this in some static cache
    title = case page do
      "link/index" -> "Global Linking"
      "link/start" -> "Start Global Linking"
      "link/online" -> "Online linking"
      "link/server" -> "Server linking"
      _ -> nil
    end

    if is_nil(title) do
      conn
      |> put_status(:bad_request)
      |> json(%{message: "invalid page"})
    else
      conn
      |> put_resp_header("cache-control", "max-age=86400, public")
      |> send_download({:binary, GlobalApi.SkinsNif.render_link_preview(title)}, filename: "preview.png", disposition: :inline)
    end
  end

  def preview(conn, _) do
    conn
    |> put_status(:bad_request)
    |> json(%{message: "no page provided"})
  end
end
