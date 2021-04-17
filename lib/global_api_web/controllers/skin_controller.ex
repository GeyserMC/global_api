defmodule GlobalApiWeb.SkinController do
  use GlobalApiWeb, :controller

  alias GlobalApi.SkinsRepo
  alias GlobalApi.Utils

  def get_skin(conn, %{"xuid" => xuid}) do
    case Utils.is_int_and_rounded(xuid) do
      false ->
        conn
        |> put_status(:bad_request)
        |> put_resp_header("cache-control", "max-age=604800, immutable, public")
        |> json(%{success: false, message: "xuid should be an int"})

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
          |> json(%{success: true, data: %{}})
        else
          conn
          |> put_resp_header("cache-control", "max-age=60, public")
          |> json(
               %{
                 success: true,
                 data: %{result | hash: Utils.hash_string(result.hash)}
               }
             )
        end
    end
  end
end
