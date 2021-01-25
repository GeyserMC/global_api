defmodule GlobalLinking.XboxApi do
  @moduledoc false
  use Supervisor
  use GlobalLinkingWeb, :controller
  alias GlobalLinking.XboxUtils
  alias GlobalLinking.Utils

  def child_spec(opts \\ []) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_) do
    state = Utils.random_string(40)
    Cachex.put(:xbox_api, :state, state)

    cached_token_data = XboxUtils.load_token_data()
    if is_nil(cached_token_data) do
      IO.puts("No cached token data found! Please sign in with state = " <> state)
      {:ok, %{refresh_token: nil, auth_token: nil, auth_token_valid_until: nil, uhs: nil, xbox_token: nil, xbox_token_valid_until: nil}}
    else
      IO.puts("Found cached token data! We'll try to use it now. Use state = " <> state <> " if you want to login with another account")
      XboxUtils.check_and_save_token_data(cached_token_data)
    end
  end

  def got_token(code) do
    case XboxUtils.start_initial_xbox_setup(code) do
      {:ok, data} ->
        :ok = GenServer.call(__MODULE__, {:got_token, data})
        XboxUtils.save_token_data(data)
      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_gamertag(xuid) do
    case get_xbox_token_and_uhs() do
      :not_setup -> :not_setup
      {xbox_token, uhs} ->
        headers = [
          {"x-xbl-contract-version", 3},
          {"Authorization", "XBL3.0 x=" <> uhs <> ";" <> xbox_token}
        ]

        {:ok, response} = HTTPoison.get("https://profile.xboxlive.com/users/xuid(" <> xuid <> ")/profile/settings?settings=Gamertag", headers)
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
      {xbox_token, uhs} ->
        headers = [
          {"x-xbl-contract-version", 3},
          {"Authorization", "XBL3.0 x=" <> uhs <> ";" <> xbox_token}
        ]

        {:ok, response} = HTTPoison.get("https://profile.xboxlive.com/users/gt(" <> gamertag <> ")/profile/settings", headers)
        response = Jason.decode!(response.body)

        users = response["profileUsers"]
        if users != nil do
          Enum.at(users, 0)["id"]
        else
          nil
        end
    end
  end

  def get_xbox_token_and_uhs() do
    {_, result} = Cachex.fetch(:xbox_api, :xbox_token_and_uhs, fn _ ->
      case GenServer.call(__MODULE__, :get_token_and_uhs) do
        {nil, _} -> {:ignore, :not_setup}
        {_, nil} -> {:ignore, :not_setup}
        {xbox_token, uhs} -> {:commit, {xbox_token, uhs}}
      end
    end)
    result
  end

  def handle_call({:got_token, data}, _from, _) do
    {:reply, :ok, data}
  end

  def handle_call(:get_token_and_uhs, _from, state) do
    if state.refresh_token == nil do
      {:reply, {nil, nil}, state}
    else
      {:ok, state} = XboxUtils.check_and_save_token_data(state)
      {:reply, {state.xbox_token, state.uhs}, state}
    end
  end
end
