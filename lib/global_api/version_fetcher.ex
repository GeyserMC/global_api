defmodule GlobalApi.VersionFetcher do
  use GenServer

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    # fetch the latest version information directly, not after x minutes
    queue_fetch(0)
    {:ok, :ok}
  end

  @impl true
  def handle_info(:fetch, state) do
    response = HTTPoison.get!("https://geysermc.org/versions.json")
    json = Jason.decode!(response.body)

    Cachex.put(:project_version, "geyser", json)

    queue_fetch()
    {:noreply, state}
  end

  defp queue_fetch(wait_millis \\ 15 * 60_0000) do
    Process.send_after(self(), :fetch, wait_millis)
  end
end
