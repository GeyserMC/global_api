defmodule GlobalApiWeb.HealthController do
  @moduledoc false
  use GlobalApiWeb, :controller

  def health(conn, _) do
    conn
    |> send_resp(:ok, "OK")
  end
end
