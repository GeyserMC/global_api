defmodule GlobalApiWeb.Skin.ItemInfoController do
  use GlobalApiWeb, :controller

  def skin_info(conn, %{"texture_id" => id}) do
    render(
      conn,
      "texture_info.html",
      page_title: "Skin info",
      page_description: "Test"
    )
  end

  def cape_info(conn, %{"texture_id" => id}) do
    render(
      conn,
      "texture_info.html",
      page_title: "Cape info",
      page_description: "Test"
    )
  end
end
