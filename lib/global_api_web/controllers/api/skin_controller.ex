defmodule GlobalApiWeb.Api.SkinController do
  use GlobalApiWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GlobalApi.SkinsRepo
  alias GlobalApi.Service.SkinService
  alias GlobalApi.Utils
  alias OpenApiSpex.Example
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
      {:error, status_code, message} ->
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
    case Utils.is_int_rounded_and_positive(xuid) do
      false ->
        conn
        |> put_status(:bad_request)
        |> put_resp_header("cache-control", "max-age=604800, immutable, public")
        |> json(%{message: "xuid should be an int"})

      true ->
        {_, result} = Cachex.fetch(
          :xuid_to_skin,
          xuid,
          fn (xuid) ->
            case SkinsRepo.get_player_skin(xuid) do
              nil ->
                {:ignore, nil} #todo why don't I cache this?
              player_skin ->
                {
                  :commit,
                  %{
                    hash: player_skin.skin.hash,
                    texture_id: player_skin.skin.texture_id,
                    value: player_skin.skin.value,
                    signature: player_skin.skin.signature,
                    is_steve: player_skin.skin.is_steve,
                    last_update: player_skin.updated_at
                  }
                }
            end
          end
        )

        if result == nil do
          conn
          |> put_resp_header("cache-control", "max-age=120, public")
          |> json(%{})
        else
          conn
          |> put_resp_header("cache-control", "max-age=60, public")
          |> json(%{result | hash: Utils.hash_string(result.hash)})
        end
    end
  end
end
