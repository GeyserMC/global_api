defmodule GlobalApiWeb.Api.NewsController do
  use GlobalApiWeb, :controller

  # v2
  def get_news(conn, %{"project" => project}) do

  end

  # to support the old v1
  def get_news(conn, _) do
    json(conn, [])
  end
end
