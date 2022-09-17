defmodule GlobalApiWeb.NotFoundError do
  # doesn't need a handle_errors fun in router, because plug_status is given
  defexception [message: "", plug_status: :not_found]
end
