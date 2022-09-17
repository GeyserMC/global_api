defmodule GlobalApiWeb.Api.XboxController do
  use GlobalApiWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GlobalApi.Utils
  alias GlobalApi.XboxAccounts
  alias GlobalApi.XboxApi
  alias GlobalApi.XboxRepo
  alias GlobalApi.XboxUtils
  alias GlobalApiWeb.Schemas

  tags ["xbox"]

  operation :get_gamertag_v2,
    summary: "Get the gamertag from a xuid",
    parameters: [
      xuid: [in: :path, description: "The xuid of the Bedrock player"]
    ],
    responses: [
      ok: {"The gamertag associated with the xuid or an empty object if there is account with the given xuid", "application/json", Schemas.XboxGamertagResult},
      bad_request: {"The xuid is invalid (not an int)", "application/json", Schemas.Error},
      service_unavailable: {"The requested account was not cached and we were not able to call the Xbox Live API (rate limited / not setup)", "application/json", Schemas.Error}
    ]

  operation :get_xuid_v2,
    summary: "Get the xuid from a gamertag",
    parameters: [
      gamertag: [in: :path, description: "The gamertag of the Bedrock player"]
    ],
    responses: [
      ok: {"The xuid associated with the gamertag or an empty object if there is account with the given gamertag", "application/json", Schemas.XboxXuidResult},
      bad_request: {"The gamertag is invalid (empty or longer than 16 chars)", "application/json", Schemas.Error},
      service_unavailable: {"The requested account was not cached and we were not able to call the Xbox Live API (rate limited / not setup)", "application/json", Schemas.Error}
    ]

  operation :get_gamertag_v1, deprecated: true
  operation :get_xuid_v1, deprecated: true
  operation :got_token, false

  operation :get_gamertag_batch, false #todo decide if we want to keep the batch endpoint

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
        json(conn, %{
          data: Enum.map(handled, fn {xuid, gamertag} -> %{xuid: xuid, gamertag: gamertag} end),
          message: message,
          not_handled: not_handled
        })
      {:error, status_code, message} ->
        conn
        |> put_status(status_code)
        |> json(%{message: message})
    end
  end

  def get_gamertag_batch(conn, %{"xuids" => _}) do
    conn
    |> put_status(:bad_request)
    |> json(%{message: "xuids is not an array or has more than 600 elements"})
  end

  def get_xuid_v2(conn, data) do
    {status, data} = get_xuid(data)
    conn
    |> put_status(status)
    |> json(data)
  end

  def get_xuid_v1(conn, data) do
    case get_xuid(data) do
      {:ok, data} -> json(conn, %{success: true, data: data})
      {_, response} -> json(conn, Map.put(response, :success, false))
    end
  end

  def get_xuid(%{"gamertag" => gamertag}) do
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
          {:service_unavailable, XboxAccounts.not_setup_response()}
        {:rate_limit, _} ->
          {:service_unavailable, %{message: "unable to handle request: too much traffic"}}
        nil ->
          {:ok, %{}}
        xuid ->
          {:ok, %{xuid: xuid}}
      end
    else
      {:bad_request, %{message: "gamertag is empty or longer than 16 chars"}}
    end
  end
end
