defmodule GlobalApiWeb.ErrorView do
  use GlobalApiWeb, :view

  def template_not_found(_, %{conn: conn}) do
    "#{conn.status} #{Plug.Conn.Status.reason_phrase(conn.status)}"
  end
end
