defmodule GlobalApiWeb.Api.NewsController do
  use GlobalApiWeb, :controller

  def get_news(conn, _) do
    json(conn, [])
  end
end
