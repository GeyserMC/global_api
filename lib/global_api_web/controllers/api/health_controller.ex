defmodule GlobalApiWeb.Api.HealthController do
  use GlobalApiWeb, :controller
  use OpenApiSpex.ControllerSpecs

  tags ["health"]

  operation :health,
    summary: "Simple server online check",
    responses: [
      no_content: "The server is online"
    ]

  def health(conn, _), do:
    send_resp(conn, :no_content, "")
end
