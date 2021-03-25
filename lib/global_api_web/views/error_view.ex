defmodule GlobalApiWeb.ErrorView do
#  use GlobalApiWeb, :view
#  import Phoenix.Controller, only: [json: 2]
#  import Plug.Conn, only: [put_resp_header: 3]

  def render("404.json", _conn) do
#  def render("404.json", conn) do
#    conn
#    |> put_resp_header("cache-content", "max-age=86400, s-maxage=86400, public")
#    |> json(%{success: false, message: "Requested page cannot be found"})
    %{success: false, message: "Requested page cannot be found"}
  end

  def render(_, _assigns) do
    %{success: false, message: "Unknown error happened while executing your request"}
  end
end
