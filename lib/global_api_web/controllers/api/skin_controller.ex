defmodule GlobalApiWeb.Api.SkinController do
  use GlobalApiWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GlobalApi.Service.SkinService
  alias GlobalApi.Utils
  alias GlobalApiWeb.Schemas

  tags ["skin"]

  operation :get_recent_uploads,
    summary: "Get a list of the most recently uploaded skins",
    parameters: [
      page: [in: :path, description: "Number between 1 - page limit. Defaults to 1", required: false, example: 1]
    ],
    responses: [
      ok: {"The most recently uploaded skins. First element has been uploaded most recently etc.", "application/json", Schemas.RecentConvertedSkinList},
      bad_request: {"Invalid page number (e.g. negative, decimal, too large)", "application/json", Schemas.Error}
    ]

  operation :get_skin,
    summary: "Get the most recently converted skin of a Bedrock player",
    parameters: [
      xuid: [in: :path, description: "Bedrock xuid", example: "2535432196048835"]
    ],
    responses: [
      ok: {"Converted skin or an empty object if there is no skin stored for that player", "application/json", Schemas.ConvertedSkin},
      bad_request: {"Invalid xuid (not an int)", "application/json", Schemas.Error}
    ]

  def get_recent_uploads(conn, %{"page" => page}) do
    case SkinService.recent_uploads(page) do
      {:error, error_type} ->
        {status_code, message} = SkinService.error_details(error_type)
        conn
        |> put_status(status_code)
        |> json(%{message: message})
      {:ok, data, total_pages, _} ->
        json(conn, %{data: data, total_pages: total_pages})
    end
  end

  def get_recent_uploads(conn, _) do
    get_recent_uploads(conn, %{"page" => 1})
  end

  def get_skin(conn, %{"xuid" => xuid}) do
    case SkinService.get_skin_by_xuid(xuid) do
      {:error, error_type} ->
        {status_code, message} = SkinService.error_details(error_type)
        conn
        |> put_status(status_code)
        |> put_resp_header("cache-control", "max-age=86400, immutable, public")
        |> json(%{message: message})
      nil ->
        # todo 204 or 404 makes more sense
        conn
        |> put_resp_header("cache-control", "max-age=120, public")
        |> json(%{})
      skin ->
        conn
        |> put_resp_header("cache-control", "max-age=60, public")
        |> json(%{skin | hash: Utils.hash_string(skin.hash)})
    end
  end
end
