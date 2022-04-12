defmodule GlobalApiWeb.Skin.SkinsController do
  @moduledoc false
  use GlobalApiWeb, :controller

  def index(conn, _) do
    redirect(conn, to: Routes.skins_path(conn, :recent_bedrock))
  end

  def recent_bedrock(conn, _) do
    render(
      conn,
      "recent_bedrock.html",
      page_title: "Most recent uploaded skins",
      page_description: "See the most recent converted Bedrock skins"
    )
  end
end
