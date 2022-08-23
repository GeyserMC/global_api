defmodule GlobalApi.VersionFetcher do
  use GenServer

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    queue_fetch()
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

  defp queue_fetch do
    Process.send_after(self(), :fetch, 15 * 60_000)
  end
end
