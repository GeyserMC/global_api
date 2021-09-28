defmodule GlobalApi.XboxApi do
  @moduledoc false
  use GenServer

  alias GlobalApi.XboxAccounts
  alias GlobalApi.Utils

  @sustain_limit 30

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_) do
    state = Utils.random_string(40)
    Cachex.put(:general, :state, state)

    cached_token_data = XboxAccounts.load_token_data()

    if is_nil(cached_token_data) do
      # make the token cache file if it doesn't exist
      XboxAccounts.save_token_data(%{updater: %{}, data: []})
    end

    updater = if !is_nil(cached_token_data) && map_size(cached_token_data.updater) != 0 do
      cached_token_data.updater
    else
      nil
    end

    if is_nil(updater) do
      IO.puts("Hey! Don't forgot to add a xbox account for the identity updater! >:(")
    end

    if is_nil(cached_token_data) do
      IO.puts("No cached token data found! Please sign in with state = " <> state)
      {
        :ok,
        %{
          data: [],
          static: [],
          updater: updater || %{},
          time_between_actions: 90,
          next_action: 0,
          round: 31,
          round_reset: 0,
          next_check: :os.system_time(:second) * 2
        }
      }
    else
      IO.puts("Found cached token data for #{length(cached_token_data.data)} account(s)! We'll try to use it now.")
      IO.puts("Use state = #{state} if you want to login with another account")
      # the endpoints we use have a limit of 30 requests per 5 minutes and 10 requests per 15 seconds,
      # so we have a round count, a round reset time, next action and time between actions for that
      case XboxAccounts.check_and_save_token_data(cached_token_data) do
        {:ok, token_data} ->
          data_acc_count = length(token_data.data)
          {
            :ok,
            %{
              data: token_data.data,
              static: token_data.data,
              updater: token_data.updater,
              time_between_actions: if data_acc_count == 0 do 0 else 11 / data_acc_count end,
              next_action: 0,
              round: 31,
              round_reset: 0,
              next_check: :os.system_time(:second) + 60 * 60
            }
          }
      end
    end
  end

  def got_token(code, is_updater) do
    code = String.replace_suffix(code, "!updater", "")
    case XboxAccounts.start_initial_xbox_setup(code) do
      {:ok, data} ->
        :ok = GenServer.call(__MODULE__, {:got_token, data, is_updater})
      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_batched_v2(entries, is_updater) when is_list(entries) do
    case get_xbox_token_and_uhs(is_updater) do
      :not_setup -> :not_setup
      {:rate_limit, rate_reset} -> {:rate_limit, rate_reset}
      {xbox_token, uhs} ->
        headers = [
          {"x-xbl-contract-version", "1"},
          {"Authorization", "XBL3.0 x=#{uhs};#{xbox_token}"},
          {"Content-Type", "application/json"},
          {"User-Agent", "XboxServicesAPI/2020.11.202102041.1 c"},
          {"Accept-Language", "en-US"},
          {"Accept", "application/json"}
        ]

        # 600 is stable, more than that becomes unstable
        body = Jason.encode!(%{xuids: entries})

        request = HTTPoison.post(
          "https://peoplehub.xboxlive.com/users/me/people/batch/decoration/broadcast,multiplayersummary,preferredcolor,socialManager",
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
              {
                :ok,
                Utils.merge_array_to_map(
                  %{},
                  json["people"],
                  fn person ->
                    # invalid xuids should be excluded, but just to be sure
                    if person["gamertag"] != nil do
                      {Utils.get_int_if_string(person["xuid"]), person["gamertag"]}
                    end
                  end
                )
              }
            end
          {:error, error} -> {:error, error.reason}
        end
    end
  end

  def get_batched(entries, is_updater) when is_list(entries) do
    case get_xbox_token_and_uhs(is_updater) do
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

  def get_gamertag(xuid) do
    case get_xbox_token_and_uhs() do
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

  def get_xuid(gamertag) do
    case get_xbox_token_and_uhs() do
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

  def get_xbox_token_and_uhs(is_updater \\ false) do
    if is_updater do
      GenServer.call(__MODULE__, :get_updater_token_and_uhs)
    else
      GenServer.call(__MODULE__, :get_token_and_uhs)
    end
  end

  @impl true
  def handle_call({:got_token, data, is_updater}, _from, state) do
    new_data = save_new_token_data(state, data, is_updater)
    # reset the timer to make sure that we don't overload the new account in the future.
    # we can only make 30 requests every 5 minutes, so I implemented a cooldown of 300 / 30 = 10 + 1 seconds.
    # then we divide that by the amount of accounts available
    {
      :reply,
      :ok,
      %{
        state |
        updater: new_data.updater,
        static: new_data.data,
        round_reset: :os.system_time(:second) + 5 * 60,
        time_between_actions: 11 / length(new_data.data)
      }
    }
  end

  @impl true
  def handle_call(:get_token_and_uhs, _from, state) do
    # data, static, next_check
    if length(state.static) == 0 do
      {:reply, :not_setup, state}
    else
      if state.next_action > :os.system_time(:millisecond) do
        {:reply, {:rate_limit, ceil(state.next_action / 1000)}}
      else
        state = reset_time_check(state)
        if state.round > @sustain_limit do
          {:reply, {:rate_limit, state.round_reset - :os.system_time(:second)}, state}
        else
          state = get_token_check(state)
          {next, state} = get_next_and_increase_round(state)
          {
            :reply,
            {next.xbox_token, next.uhs},
            %{state | next_action: :os.system_time(:millisecond) + state.time_between_actions}
          }
        end
      end
    end
  end

  @impl true
  def handle_call(:get_updater_token_and_uhs, _from, state) do
    # what makes the updater unique is that the updates are scheduled,
    # so we only have to check if we have an updater and return it if we do
    if map_size(state.updater) == 0 do
      {:reply, :not_setup, state}
    else
      state = get_token_check(state)
      {:reply, {state.updater.xbox_token, state.updater.uhs}, state}
    end
  end

  defp save_new_token_data(state, data, is_updater) do
    ret = if is_updater do
      %{updater: data, data: state.static}
    else
      %{updater: state.updater, data: [data | state.static]}
    end
    XboxAccounts.save_token_data(ret)
    ret
  end

  defp reset_time_check(state) do
    if state.round_reset < :os.system_time(:second) do
      %{state | round_reset: :os.system_time(:second) + 5 * 60, round: 1}
    else
      state
    end
  end

  defp get_next_and_increase_round(state) do
    [next | data] = state.data
    if data == [] do
      {next, %{state | data: state.static, round: state.round + 1}}
    else
      {next, %{state | data: data}}
    end
  end

  defp get_token_check(state) do
    if state.next_check < :os.system_time(:second) do
      case XboxAccounts.check_and_save_token_data(state) do
        {:ok, token_data} ->
          %{state | updater: token_data.updater, data: token_data.data, static: token_data.data, next_check: :os.system_time(:second) + 60 * 60}
        {:error, reason} ->
          IO.puts("Error whilst checking! #{reason}. Will reset all accs just to be sure")
          %{state | updater: [], data: [], static: [], next_check: :os.system_time(:second) * 2}
      end
    else
      state
    end
  end
end
