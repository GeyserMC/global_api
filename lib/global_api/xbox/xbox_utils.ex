defmodule GlobalApi.XboxUtils do
  use GenServer

  alias GlobalApi.Utils
  alias GlobalApi.XboxAccounts

  @known_rate_limit_types [:profile, :social]
  # burst, sustain
  @known_rate_limit_values [{10, 30}, {10, 30}]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_) do
    state = Utils.random_string(40)
    Cachex.put(:general, :state, state)

    result = %{
      accounts: [],
      account_loop: [],
      rate_limits: %{},
      updater: %{},
      next_check: :os.system_time(:seconds) + 60 * 60
    }

    result =
      case XboxAccounts.load_token_data() do
        nil ->
          # make the token cache file if it doesn't exist
          XboxAccounts.save_token_data([], %{})

          IO.puts("No cached token data found! Please sign in with state = #{state}")
        {accounts, updater} ->
          if is_nil(updater) do
            IO.puts("Hey! Don't forgot to add a xbox account for the identity updater! >:(")
          end

          IO.puts(
            "Found cached token data for #{length(accounts)} account(s)! We'll try to use them now."
          )
          case XboxAccounts.check_and_save_token_data(accounts, updater) do
            {:ok, accounts, updater} ->
              Map.put(result, :updater, updater || %{})
              |> add_accounts(accounts)
          end
      end

    IO.puts("Use state = #{state} if you want to login with another account")
    IO.inspect(result)
    {:ok, result}
  end

  defp add_accounts(state, []), do: state
  defp add_accounts(state, [account | remaining]),
       do: add_accounts(add_account(state, account), remaining)

  defp add_account(state, account) do
    id = Utils.first_unused_number(state.accounts, fn account -> account.id end)
    account = Map.put(account, :id, id)

    # we have to add the new accounts at the end of the lists, otherwise the rate limit order is messed up
    accounts = state.accounts ++ [account]
    account_loop = state.account_loop ++ [account]
    rate_limit =
      for i <- 0..(length(@known_rate_limit_types) - 1),
          into: %{},
          do: {
            Enum.at(@known_rate_limit_types, i),
            create_rate_limit(Enum.at(@known_rate_limit_values, i))
          }
    state
    |> Map.put(:accounts, accounts)
    |> Map.put(:account_loop, account_loop)
    |> Map.put(:rate_limits, Map.put(state.rate_limits, account.id, rate_limit))
  end

  defp create_rate_limit({burst_limit, sustain_limit}) do
    %{
      burst_limit: burst_limit,
      sustain_limit: sustain_limit,
      burst_request_count: 0,
      sustain_request_count: 0,
      next_burst: :os.system_time(:millisecond) + (15 * 1000),
      next_sustain: :os.system_time(:millisecond) + (5 * 60 * 1000)
    }
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

  def get_xbox_token_and_uhs(rate_limit_type, is_updater \\ false) do
    if is_updater do
      GenServer.call(__MODULE__, :get_updater_token_and_uhs)
    else
      GenServer.call(__MODULE__, {:get_token_and_uhs, rate_limit_type})
    end
  end

  @impl true
  def handle_call({:got_token, data, is_updater}, _from, state) do
    {:reply, :ok, add_and_save_new_token_data(state, data, is_updater)}
  end

  @impl true
  def handle_call({:get_token_and_uhs, rate_limit_type}, _from, state) do
    # data, accounts, next_check
    if length(state.accounts) == 0 do
      {:reply, :not_setup, state}
    else
      # check if the tokens are still valid
      state = validate_tokens_check(state)

      {account, state} = get_next_account(state)
      case state.rate_limits[account.id][rate_limit_type] do
        nil -> {:reply, :invalid_rate_limit_type, state}
        rate_limit ->
          rate_limit = reset_time_check(rate_limit)

          if rate_limit.burst_request_count >= rate_limit.burst_limit do
            state = put_in(state.rate_limits[account.id][rate_limit_type], rate_limit)
            {:reply, {:rate_limit, ceil(rate_limit.next_burst / 1000)}, state}
          else
            if rate_limit.sustain_request_count >= rate_limit.sustain_limit do
              state = put_in(state.rate_limits[account.id][rate_limit_type], rate_limit)
              {:reply, {:rate_limit, ceil(rate_limit.next_sustain / 1000)}, state}
            else
              rate_limit = %{
                rate_limit |
                burst_request_count: rate_limit.burst_request_count + 1,
                sustain_request_count: rate_limit.sustain_request_count + 1
              }
              state = put_in(state.rate_limits[account.id][rate_limit_type], rate_limit)

              {
                :reply,
                {account.xbox_token, account.uhs},
                state
              }
            end
          end
      end
    end
  end

  @impl true
  def handle_call(:get_updater_token_and_uhs, _from, state) do
    # what makes the updater unique is that the updates are scheduled,
    # so we only have to check if we have an updater and return it
    if map_size(state.updater) == 0 do
      {:reply, :not_setup, state}
    else
      state = validate_tokens_check(state)
      {:reply, {state.updater.xbox_token, state.updater.uhs}, state}
    end
  end

  defp add_and_save_new_token_data(state, data, is_updater) do
    if is_updater do
      XboxAccounts.save_token_data(state.accounts, data)
      Map.put(state, :updater, data)
    else
      state = add_account(state, data)
      XboxAccounts.save_token_data(state.accounts, state.updater)
      state
    end
  end

  defp reset_time_check(rate_limit) do
    rate_limit
    |> reset_burst_check
    |> reset_sustain_check
  end

  defp reset_burst_check(rate_limit) do
    if rate_limit.next_burst < :os.system_time(:millisecond) do
      %{rate_limit | next_burst: rate_limit.next_burst + 15 * 1000, burst_request_count: 0}
    else
      rate_limit
    end
  end

  defp reset_sustain_check(rate_limit) do
    if rate_limit.next_sustain < :os.system_time(:millisecond) do
      %{rate_limit | next_sustain: rate_limit.next_sustain + 5 * 60 * 1000, sustain_request_count: 0}
    else
      rate_limit
    end
  end

  defp get_next_account(state) do
    [next | remaining] = state.account_loop
    case remaining do
      [] ->  {next, %{state | account_loop: state.accounts}}
      _ -> {next, %{state | account_loop: remaining}}
    end
  end

  defp validate_tokens_check(state) do
    if state.next_check > :os.system_time(:second) do
       state
    else
      case XboxAccounts.check_and_save_token_data(state.accounts, state.updater) do
        {:ok, accounts, updater} ->
          # accounts will be backwards, but it doesn't matter because every account has an id.
          # however, we have to update the account loop to use the new token data
          account_loop = Enum.map(
            state.account_loop,
            fn account ->
              case Enum.find(accounts, fn x -> x.id == account.id end) do
                nil -> account
                x -> x
              end
            end)

          %{
            state |
            accounts: accounts,
            account_loop: account_loop,
            updater: updater,
            next_check: :os.system_time(:second) + 60 * 60
          }
        {:error, reason} ->
          IO.puts("Error whilst checking tokens! #{reason}. Will try it again in 60 sec")
          %{state | next_check: :os.system_time(:second) + 60}
      end
    end
  end
end
