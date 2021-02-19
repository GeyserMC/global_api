defmodule GlobalApiWeb.XboxController do
  use GlobalApiWeb, :controller

  alias GlobalApi.CustomMetrics
  alias GlobalApi.Utils
  alias GlobalApi.XboxApi
  alias GlobalApi.XboxUtils

  # we can't specify the cache headers in cloudflare for this
  def got_token(conn, %{"code" => code, "state" => state}) do
    {:ok, correct_state} = Cachex.get(:xbox_api, :state)
    if String.equivalent?(correct_state, state) do
      case XboxApi.got_token(code) do
        :ok -> json(conn, :ok)
        {:error, reason} -> json(conn, %{error: reason})
      end
    else
      json(conn, "I'm sorry, but what did you try to do?")
    end
  end

  def got_token(conn, _) do
    json(conn, "I'm sorry, but what did you try to do?")
  end

  def get_gamertag(conn, %{"xuid" => xuid}) do
    case Utils.is_int_and_rounded(xuid) do
      false ->
        conn
        |> put_status(:bad_request)
        |> put_resp_header("cache-control", "max-age=604800, s-max-age=604800, immutable, public")
        |> json(%{success: false, message: "xuid should be an int"})

      true ->
        CustomMetrics.add(:get_gamertag)

        {_, gamertag} = Cachex.fetch(
          :get_gamertag,
          xuid,
          fn _ ->
            case XboxApi.get_gamertag(xuid) do
              :not_setup -> {:ignore, :not_setup}
              gamertag -> {:commit, gamertag}
            end
          end
        )

        case gamertag do
          :not_setup ->
            conn
            |> put_resp_header("cache-control", "max-age=300, s-maxage=300, public")
            |> json(XboxUtils.not_setup_message())
          nil ->
            conn
            |> put_resp_header("cache-control", "max-age=900, s-maxage=900, public")
            |> json(%{success: true, data: %{}})
          gamertag ->
            conn
            |> put_resp_header("cache-control", "public, max-age=1800, s-maxage=1800")
            |> json(
                 %{
                   success: true,
                   data: %{
                     gamertag: gamertag
                   }
                 }
               )
        end
    end
  end

  def get_xuid(conn, %{"gamertag" => gamertag}) do
    if Utils.is_in_range(gamertag, 1, 16) do
      CustomMetrics.add(:get_xuid)

      {_, xuid} = Cachex.fetch(
        :get_xuid,
        gamertag,
        fn _ ->
          case XboxApi.get_xuid(gamertag) do
            :not_setup -> {:ignore, :not_setup}
            xuid -> {:commit, xuid}
          end
        end
      )

      case xuid do
        :not_setup ->
          conn
          |> put_resp_header("cache-control", "max-age=300, s-maxage=300, public")
          |> json(XboxUtils.not_setup_message())
        nil ->
          conn
          |> put_resp_header("cache-control", "max-age=900, s-maxage=900, public")
          |> json(%{success: true, data: %{}})
        xuid ->
          conn
          |> put_resp_header("cache-control", "max-age=1800, s-maxage=1800, public")
          |> json(
               %{
                 success: true,
                 data: %{
                   xuid: xuid
                 }
               }
             )
      end
    else
      conn
      |> put_status(:bad_request)
      |> put_resp_header("cache-control", "max-age=604800, s-maxage=604800, immutable, public")
      |> json(%{success: false, message: "Gamertag is empty or longer than 16 chars"})
    end
  end
end
