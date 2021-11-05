defmodule GlobalApiWeb.Skin.SkinsController do
  @moduledoc false
  use GlobalApiWeb, :controller

  def index(conn, _) do
    render(
      conn,
      "index.html",
      page_title: "Most recent uploaded skins",
      page_description: "See the most recent converted Bedrock skins"
    )
  end
end
