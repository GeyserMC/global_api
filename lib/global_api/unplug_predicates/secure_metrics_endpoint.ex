defmodule GlobalApi.UnplugPredicates.SecureMetricsEndpoint do
  @behaviour Unplug.Predicate

  alias GlobalApi.Utils

  @impl true
  def call(conn, _) do
    auth_header = Plug.Conn.get_req_header(conn, "authorization")
    if length(auth_header) == 1 do
      [auth_header | []] = auth_header
      Utils.get_env(:app, :metrics_auth) == auth_header
    end
  end
end
