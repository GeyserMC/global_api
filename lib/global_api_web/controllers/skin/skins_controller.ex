defmodule GlobalApiWeb.Skin.SkinsController do
  @moduledoc false
  use GlobalApiWeb, :controller

  def index(conn, _) do
    render(
      conn,
      "index.html",
      page_title: "test",
      page_description: "uwu"
    )
  end
end
