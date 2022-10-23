defmodule GlobalApi.IdentityUpdater do
  use GenServer

  alias GlobalApi.XboxApi
  alias GlobalApi.XboxRepo

  # the rate limit is 30 requests per 300 seconds,
  # so that's one request every 10 seconds + 1 second to be sure
  # divide by 2 because we use 2 endpoints to update xuid. They both have the same rate limit,
  # but they fall under a different category and thus we can divide the check time by 2
  @check_time ceil(11 / 2)

  @identity_update_threshold 48 * 60 * 60 * 1000 # 48 hours

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    check_after_seconds()
    {:ok, %{v2: true}}
  end

  @impl true
  def handle_info(:update, %{v2: is_v2}) do
    # it's getting unstable when you go much over the 600
    identities = XboxRepo.get_least_recent_updated(if is_v2 do 600 else 75 end)
    if length(identities) > 0 do
      least_recent = List.first(identities)
      # if the least recent entry hasn't been updated and passes the threshold
      if System.system_time(:millisecond) - least_recent.inserted_at > @identity_update_threshold do
        # update it :)
        update0(identities, is_v2)

        check_after_seconds()
      else
        # we can wait until the least recent entry passed the threshold
        check_after_millis(least_recent.inserted_at + @identity_update_threshold - System.system_time(:millisecond))
      end
    else
      check_after_seconds(60 * 60)
    end
    {:noreply, %{v2: !is_v2}}
#    {:noreply, %{v2: true}}
  end

  defp update0(identities, true) do
    list = Enum.map(identities, fn identity -> identity.xuid end)
    case XboxApi.request_big_batch(list, true, true) do
      {:ok, data} ->
        time = System.system_time(:millisecond)
        mapped = Enum.map(data, fn {xuid, gamertag} -> [xuid: xuid, gamertag: gamertag, inserted_at: time] end)
        XboxRepo.insert_bulk(mapped)
      _ -> :ignore # everything else can be ignored
    end
  end

  defp update0(identities, false) do
    list = Enum.map(identities, fn identity -> identity.xuid end)
    case XboxApi.request_batch(list, true) do
      {:ok, data} ->
        time = System.system_time(:millisecond)
        mapped = Enum.map(data, fn {xuid, gamertag} -> [xuid: xuid, gamertag: gamertag, inserted_at: time] end)
        XboxRepo.insert_bulk(mapped)
      _ -> :ignore # everything else can be ignored
    end
  end

  defp check_after_millis(check_time), do: Process.send_after(self(), :update, check_time)
  defp check_after_seconds(check_time \\ @check_time), do: check_after_millis(check_time * 1000)
end
