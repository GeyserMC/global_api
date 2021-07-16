defmodule GlobalApiWeb.XboxController do
  use GlobalApiWeb, :controller

  alias GlobalApi.Utils
  alias GlobalApi.XboxApi
  alias GlobalApi.XboxRepo
  alias GlobalApi.XboxUtils

  # we can't specify the cache headers in cloudflare for this
  def got_token(conn, %{"code" => code, "state" => state}) do
    {:ok, correct_state} = Cachex.get(:general, :state)
    is_updater = String.equivalent?(correct_state <> "!updater", state)
    if String.equivalent?(correct_state, state) || is_updater do
      case XboxApi.got_token(code, is_updater) do
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
        |> put_resp_header("cache-control", "max-age=604800, immutable, public")
        |> json(%{success: false, message: "xuid should be an int"})

      true ->
        {_, gamertag} = Cachex.fetch(
          :get_gamertag,
          xuid,
          fn _ ->
            xuid = Utils.get_int_if_string(xuid)
            identity = XboxRepo.get_by_xuid(xuid)
            if identity != nil do
              {:commit, identity.gamertag}
            else
              gamertag = XboxApi.get_gamertag(xuid)
              # save if succeeded
              if is_binary(gamertag) do
                XboxRepo.insert_new(xuid, gamertag)
              end
              {:commit, gamertag}
            end
          end
        )

        case gamertag do
          :not_setup ->
            conn
            |> put_resp_header("cache-control", "max-age=300, public")
            |> json(XboxUtils.not_setup_message())
          {:rate_limit, rate_reset} ->
            conn
            |> put_resp_header("cache-control", "max-age=#{rate_reset}, public")
            |> json(%{success: false, message: "unable to handle request: too much traffic"})
          nil ->
            conn
            |> put_resp_header("cache-control", "max-age=900, public")
            |> json(%{success: true, data: %{}})
          gamertag ->
            conn
            |> put_resp_header("cache-control", "max-age=60, public")
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
      {_, xuid} = Cachex.fetch(
        :get_xuid,
        gamertag,
        fn _ ->
          identity = XboxRepo.get_by_gamertag(gamertag)
          if identity != nil do
            {:commit, identity.xuid}
          else
            xuid = XboxApi.get_xuid(gamertag)
            # save if succeeded
            if is_binary(xuid) do
              XboxRepo.insert_new(xuid, gamertag)
            end
            {:commit, xuid}
          end
        end
      )

      case xuid do
        :not_setup ->
          conn
          |> put_resp_header("cache-control", "max-age=300, public")
          |> json(XboxUtils.not_setup_message())
        {:rate_limit, rate_reset} ->
          conn
          |> put_resp_header("cache-control", "max-age=#{rate_reset}, public")
          |> json(%{success: false, message: "unable to handle request: too much traffic"})
        nil ->
          conn
          |> put_resp_header("cache-control", "max-age=900, public")
          |> json(%{success: true, data: %{}})
        xuid ->
          conn
          |> put_resp_header("cache-control", "max-age=60, public")
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
      |> put_resp_header("cache-control", "max-age=604800, immutable, public")
      |> json(%{success: false, message: "gamertag is empty or longer than 16 chars"})
    end
  end
end
