defmodule GlobalApiWeb.Api.NewsController do
  use GlobalApiWeb, :controller

  # v2
  def get_news(conn, %{"project" => project}) do
    #todo edit
    json(
      conn,
      [
        %{
          id: 0,
          active: true,
          message: %{
            id: 5,
            args: [
              "Global Api",
              "2021-10-15 8:30UTC"
            ]
          },
          url: "https://google.com"
        }
      ]
    )
  end

  # to support the old v1
  def get_news(conn, _) do
    json(conn, [])
  end
end
