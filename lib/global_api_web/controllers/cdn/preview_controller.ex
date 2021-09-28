defmodule GlobalApiWeb.Cdn.PreviewController do
  @moduledoc false
  use GlobalApiWeb, :controller

  def preview(conn, %{"controller" => controller, "action" => action}) do
    conn = put_resp_header(conn, "cache-control", "max-age=86400, public")

    try do
      # controllers and actions should always be loaded
      controller = String.to_existing_atom(controller)
      action = String.to_existing_atom(action)

      # get required info from the controllers that support previews
      preview_info = apply(controller, :preview_info, [action])

      if is_nil(preview_info) do
        conn
        |> put_status(:bad_request)
        |> json(%{message: "invalid page"})
      else
        result = case preview_info do
          {:link, title} -> GlobalApi.SkinsNif.render_link_preview(title)
        end

        send_download(conn, {:binary, result}, filename: "preview.png", disposition: :inline)
      end
    rescue
      _ in [UndefinedFunctionError, ArgumentError] ->
        conn
        |> put_status(:bad_request)
        |> json(%{message: "invalid page"})
    end
  end

  def preview(conn, _) do
    conn
    |> put_status(:bad_request)
    |> put_resp_header("cache-control", "max-age=86400, public")
    |> json(%{message: "no page provided"})
  end
end
