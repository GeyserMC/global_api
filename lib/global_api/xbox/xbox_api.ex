defmodule GlobalApi.XboxApi do
  alias GlobalApi.Utils
  alias GlobalApi.XboxAccounts
  alias GlobalApi.XboxRepo
  alias GlobalApi.XboxUtils

  @doc """
  Calling this method will first check which xuids are cached, then it'll fetch from the database and
  after that it'll fetch from the official xbox api.
  """
  def get_gamertag_batch([]), do: {:ok, []}
  def get_gamertag_batch(xuids), do: get_gamertag_batch([], [], xuids, :cache)

  defp get_gamertag_batch(handled, [], [], :cache), do: {:ok, handled}
  defp get_gamertag_batch(handled, not_found, [], :cache),
       do: get_gamertag_batch(handled, not_found, :database)

  defp get_gamertag_batch(handled, not_found, [head | tail], :cache) do
    case Utils.is_int_rounded_and_positive(head) do
      false ->
        {:error, "entries contained an invalid xuid"}
      true ->
        xuid = Utils.get_int_if_string(head)

        {:ok, gamertag} = Cachex.get(:get_gamertag, xuid)
        if is_nil(gamertag) do
          get_gamertag_batch(handled, [xuid | not_found], tail, :cache)
        else
          get_gamertag_batch([%{xuid: xuid, gamertag: gamertag} | handled], not_found, tail, :cache)
        end
    end
  end

  defp get_gamertag_batch(handled, to_handle, :database) do
    players_found = XboxRepo.get_by_xuid_bulk(to_handle)

    Cachex.put_many(:get_gamertag, Enum.map(players_found, fn player -> {player.xuid, player.gamertag} end))
    Cachex.put_many(:get_xuid, Enum.map(players_found, fn player -> {player.gamertag, player.xuid} end))

    handled = handled ++ players_found

    to_reject = Utils.map_array_to_array(players_found, fn player -> player.xuid end)
    to_handle = Enum.reject(to_handle, fn xuid -> xuid in to_reject end)

    if length(to_handle) > 0 do
      get_gamertag_batch(handled, to_handle, :request)
    else
      {:ok, handled}
    end
  end

  defp get_gamertag_batch(handled, to_handle, :request) do
    case request_big_batch(to_handle, false, false) do
      :not_setup ->
        {
          :part,
          XboxAccounts.not_setup_message(),
          handled,
          to_handle
        }
      {:rate_limit, _} -> {:part, "rate limited", handled, to_handle}
      {:ok, data} ->
        Cachex.put_many(:get_gamertag, data)
        Cachex.put_many(:get_xuid, Enum.map(data, fn {xuid, gamertag} -> {gamertag, xuid} end))

        time = :os.system_time(:millisecond)
        database_data = Enum.map(data, fn {xuid, gamertag} -> [xuid: xuid, gamertag: gamertag, inserted_at: time] end)
        XboxRepo.insert_bulk(database_data)

        data = Enum.map(data, fn {xuid, gamertag} -> %{xuid: xuid, gamertag: gamertag} end)
        {:ok, handled ++ data}
      {:error, _} ->
        {:part, "an unknown error occurred", handled, to_handle}
    end
  end

  @doc """
  This is a special version of XboxApi.request_batch/1 for big batches (more than 75 xuids)
  """
  def request_big_batch(entries, to_map, is_updater) when is_list(entries) do
    case XboxUtils.get_xbox_token_and_uhs(:social, is_updater) do
      :not_setup -> :not_setup
      {:rate_limit, rate_reset} -> {:rate_limit, rate_reset}
      {xbox_token, uhs} ->
        headers = [
          {"x-xbl-contract-version", "1"},
          {"Authorization", "XBL3.0 x=#{uhs};#{xbox_token}"},
          {"Content-Type", "application/json"},
          {"Accept-Language", "en-US"},
          {"Accept", "application/json"}
        ]

        # 600 is stable, more than that becomes unstable
        body = Jason.encode!(%{xuids: entries})

        request = HTTPoison.post(
          "https://peoplehub.xboxlive.com/users/me/people/batch/decoration/presenceDetail",
          body,
          headers,
          [
            hackney: [
              pool: false
            ],
            recv_timeout: 7500
          ]
        )

        case request do
          {:ok, response} ->
            if response.status_code != 200 do
              IO.puts("#{inspect(response)}")
              if response.status_code != 429 do
                Sentry.capture_message("Xbox Api (batched v2) returned #{response.status_code}\n\n#{inspect(response)}")
                {:error, "invalid response code"}
              else
                {:error, "rate-limited"}
              end
            else
              json = Jason.decode!(response.body)

              args = [
                json["people"],
                fn person ->
                  # the data is invalid when gamertag is nil
                  if person["gamertag"] != nil do
                    {Utils.get_int_if_string(person["xuid"]), person["gamertag"]}
                  end
                end
              ]
              try do
                {:ok, if to_map do apply(&Map.new/2, args) else apply(&Enum.map/2, args) end}
              rescue
                e in ArgumentError ->
                  # sometimes the xbox api sends nonsense. we'll just ignore it
                  {:error, "the xbox api returned an invalid response"}
              end
            end
          {:error, error} -> {:error, error.reason}
        end
    end
  end

  def request_batch(entries, is_updater) when is_list(entries) do
    case XboxUtils.get_xbox_token_and_uhs(:profile, is_updater) do
      :not_setup -> :not_setup
      {:rate_limit, rate_reset} -> {:rate_limit, rate_reset}
      {xbox_token, uhs} ->
        headers = [
          {"x-xbl-contract-version", "2"},
          {"Authorization", "XBL3.0 x=#{uhs};#{xbox_token}"},
          {"content-type", "application/json"}
        ]

        body = Jason.encode!(%{userIds: entries, settings: ["Gamertag"]})

        request = HTTPoison.post(
          "https://profile.xboxlive.com/users/batch/profile/settings",
          body,
          headers,
          [
            hackney: [
              pool: false
            ]
          ]
        )

        case request do
          {:ok, response} ->
            if response.status_code != 200 do
              Sentry.capture_message("Xbox Api (batched) returned #{response.status_code}\n\n#{inspect(response)}")
              if response.status_code != 429 do
                {:error, "invalid response code"}
              else
                {:error, "rate-limited"}
              end
              case List.keyfind(headers, "WWW-Authenticate", 0) do
                {_, value} -> {:error, Enum.at(String.split(value, "error="), 1)}
                nil -> {:error, "error while making a request to xbox live"}
              end
            else
              json = Jason.decode!(response.body)
              users = json["profileUsers"]
              if users != nil do
                {
                  :ok,
                  Enum.map(
                    users,
                    fn user -> {Utils.get_int_if_string(user["id"]), Enum.at(user["settings"], 0)["value"]} end
                  )
                }
              else
                description = json["description"]
                # unfortunately it only shows 1 invalid xuid,
                # so we have to make multiple requests if there are multiple invalid xuids
                if String.starts_with?(description, "Xuid ") && String.ends_with?(description, " is invalid") do
                  {:invalid, Enum.at(String.split(description, " "), 1)}
                else
                  {:error, json}
                end
              end
            end
          {:error, reason} -> {:error, reason}
        end
    end
  end

  def request_gamertag(xuid) do
    case XboxUtils.get_xbox_token_and_uhs(:profile) do
      :not_setup -> :not_setup
      {:rate_limit, rate_reset} -> {:rate_limit, rate_reset}
      {xbox_token, uhs} ->
        headers = [
          {"x-xbl-contract-version", 3},
          {"Authorization", "XBL3.0 x=" <> uhs <> ";" <> xbox_token}
        ]

        {:ok, response} = HTTPoison.get(
          "https://profile.xboxlive.com/users/xuid(" <> xuid <> ")/profile/settings?settings=Gamertag",
          headers,
          [
            hackney: [
              pool: false
            ]
          ]
        )
        response = Jason.decode!(response.body)

        users = response["profileUsers"]
        if users != nil do
          Enum.at(Enum.at(users, 0)["settings"], 0)["value"]
        else
          nil
        end
    end
  end

  def request_xuid(gamertag) do
    case XboxUtils.get_xbox_token_and_uhs(:profile) do
      :not_setup -> :not_setup
      {:rate_limit, rate_reset} -> {:rate_limit, rate_reset}
      {xbox_token, uhs} ->
        headers = [
          {"x-xbl-contract-version", 3},
          {"Authorization", "XBL3.0 x=" <> uhs <> ";" <> xbox_token}
        ]

        {:ok, response} = HTTPoison.get(
          "https://profile.xboxlive.com/users/gt(" <> gamertag <> ")/profile/settings",
          headers,
          [
            hackney: [
              pool: false
            ]
          ]
        )
        response = Jason.decode!(response.body)

        users = response["profileUsers"]
        if users != nil do
          Enum.at(users, 0)["id"]
        else
          nil
        end
    end
  end

  def get_own_profile_info(uhs, xbox_token) do
    headers = [
      {"x-xbl-contract-version", 2},
      {"Authorization", "XBL3.0 x=" <> uhs <> ";" <> xbox_token}
    ]

    {:ok, response} = HTTPoison.get(
      "https://profile.xboxlive.com/users/me/profile/settings?settings=Gamertag",
      headers
    )
    response = Jason.decode!(response.body)

    users = response["profileUsers"]
    user = Enum.at(users, 0)
    # xuid and gamertag
    {user["id"], Enum.at(user["settings"], 0)["value"]}
  end
end
