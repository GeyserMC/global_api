defmodule GlobalApi.IdentityUpdater do
  use GenServer

  alias GlobalApi.XboxApi
  alias GlobalApi.XboxRepo

  @identity_update_threshold 60 * 60 * 24 * 1000 # one day

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    schedule()
    {:ok, :ok}
  end

  @impl true
  def handle_info(:update, state) do
    # the batch limit is 75
    identities = XboxRepo.get_least_recent_updated(75)
    if length(identities) > 0 do
      least_recent = List.first(identities)
      # if the least recent entry hasn't been updated and passes the threshold
      if :os.system_time(:millisecond) - least_recent.inserted_at > @identity_update_threshold do
        # update it :)
        update0(identities)

        # we'll take the lowest check time since we don't know if the following least-recent
        # entry also passed the threshold
        schedule()
      else
        # we can wait until the least recent entry passed the 24 hours
        schedule(least_recent.inserted_at + @identity_update_threshold - :os.system_time(:millisecond))
      end
    else
      schedule(60 * 60)
    end
    {:noreply, state}
  end

  defp update0(identities) do
    list = Enum.map(identities, fn identity -> identity.xuid end)
    response = XboxApi.get_batched(list, true)
    case response do
      {:ok, data} ->
        time = :os.system_time(:millisecond)
        data = Enum.map(data, fn {xuid, gamertag} -> [xuid: xuid, gamertag: gamertag, inserted_at: time] end)
        XboxRepo.insert_bulk(data)
      {:invalid, xuid} ->
        XboxRepo.remove_by_xuid(xuid)
        # the easiest thing to do is just retry it in the next cycle.
        # unfortunately you need one request for one invalid xuid,
        # so if there are multiple invalid xuids you need multiple requests
      {:error, _} -> :ignore # we'll try it again later
      :not_setup -> :ignore # guess we'll have to wait until it is setup
    end
  end

  defp schedule(check_time \\ 11) do
    # The rate limit is 30 requests per 300 seconds,
    # that's one request every 10 seconds + 1 second just to be sure
    Process.send_after(self(), :update, max(11, check_time) * 1000)
  end
end
