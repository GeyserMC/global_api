defmodule GlobalApiWeb.Api.XboxController do
  use GlobalApiWeb, :controller

  alias GlobalApi.Utils
  alias GlobalApi.XboxAccounts
  alias GlobalApi.XboxApi
  alias GlobalApi.XboxRepo
  alias GlobalApi.XboxUtils

  #todo all requests of :get_gamertag and :get_xuid should use an int as key, not a string

  def got_token(conn, %{"code" => code, "state" => state}) do
    {:ok, correct_state} = Cachex.get(:general, :state)
    is_updater = String.equivalent?(correct_state <> "!updater", state)
    if String.equivalent?(correct_state, state) || is_updater do
      case XboxUtils.got_token(code, is_updater) do
        :ok -> json(conn, :ok)
        {:error, reason} -> json(conn, %{message: reason})
      end
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{message: "permission denied"})
    end
  end

  def got_token(conn, _) do
    conn
    |> put_status(:unauthorized)
    |> json(%{message: "permission denied"})
  end

  def get_gamertag_v2(conn, data) do
    {status, data} = get_gamertag(data)
    conn
    |> put_status(status)
    |> json(data)
  end

  def get_gamertag_v1(conn, data) do
    case get_gamertag(data) do
      {:ok, data} -> json(conn, %{success: true, data: data})
      {_, response} -> json(conn, Map.put(response, :success, false))
    end
  end

  def get_gamertag(%{"xuid" => xuid}) do
    case Utils.is_int_rounded_and_positive(xuid) do
      false ->
        {:bad_request, %{message: "xuid should be an int"}}
      true ->
        xuid = Utils.get_int_if_string(xuid)

        {_, gamertag} = Cachex.fetch(
          :get_gamertag,
          xuid,
          fn _ ->
            identity = XboxRepo.get_by_xuid(xuid)
            if identity != nil do
              {:commit, identity.gamertag}
            else
              gamertag = XboxApi.request_gamertag(xuid)
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
            {:service_unavailable, XboxAccounts.not_setup_response()}
          {:rate_limit, _} ->
            {:service_unavailable, %{message: "unable to handle request: too much traffic"}}
          nil ->
            {:ok, %{}}
          gamertag ->
            {:ok, %{gamertag: gamertag}}
        end
    end
  end

  def get_gamertag_batch(conn, %{"xuids" => xuids}) when is_list(xuids) and length(xuids) <= 600 do
    case XboxApi.get_gamertag_batch(xuids) do
      {:ok, data} ->
        json(conn, %{data: data})
      {:part, message, handled, not_handled} ->
        json(conn, %{data: handled, message: message, not_handled: not_handled})
      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> json(%{message: message})
    end
  end

  def get_gamertag_batch(conn, %{"xuids" => _}) do
    conn
    |> put_status(:bad_request)
    |> json(%{message: "xuids is not an array or has more than 75 elements"})
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
            xuid = XboxApi.request_xuid(gamertag)
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
          |> put_status(:service_unavailable)
          |> put_resp_header("cache-control", "max-age=300, public")
          |> json(XboxAccounts.not_setup_response())
        {:rate_limit, rate_reset} ->
          conn
          |> put_status(:service_unavailable)
          |> put_resp_header("cache-control", "max-age=#{rate_reset}, public")
          |> json(%{message: "unable to handle request: too much traffic"})
        nil ->
          conn
          |> put_resp_header("cache-control", "max-age=900, public")
          |> json(%{})
        xuid ->
          conn
          |> put_resp_header("cache-control", "max-age=60, public")
          |> json(%{xuid: xuid})
      end
    else
      conn
      |> put_status(:bad_request)
      |> put_resp_header("cache-control", "max-age=604800, immutable, public")
      |> json(%{message: "gamertag is empty or longer than 16 chars"})
    end
  end
end
