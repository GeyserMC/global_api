defmodule GlobalApiWeb.RootController do
  @moduledoc false
  use GlobalApiWeb, :controller

  def get_index(conn, _) do
    conn
    |> put_resp_header("content-type", "text/html;charset=utf-8")
    |> Plug.Conn.send_file(200, "priv/static/index.html")
  end
end
