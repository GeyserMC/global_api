defmodule GlobalApi.MetricsUploader do
  use GenServer

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    #todo we can check if the message exists and create it (+ store it) if it doesn't
    webhook_url = Application.get_env(:global_api, :webhook)[:url]
    {:ok, webhook_url}
  end

  def upload(time_based_metrics, custom_fields, global_fields, system_fields) do
    GenServer.cast(__MODULE__, {time_based_metrics, custom_fields, global_fields, system_fields})
  end

  @impl true
  def handle_cast({time_based_metrics, custom_fields, global_fields, system_fields}, webhook_url) do
    HTTPoison.patch(
      webhook_url,
      Jason.encode!(
        %{
          embeds: Enum.concat(
            time_based_metrics,
            [
              %{
                description: "The number of received requests in the last 60 seconds",
                color: 4886754,
                fields: custom_fields
              },
              %{
                description: "A few global stats",
                color: 4886754,
                fields: global_fields
              },
              %{
                description: "System information",
                color: 4886754,
                timestamp: DateTime.utc_now()
                           |> DateTime.to_iso8601(),
                fields: system_fields
              }
            ]
          )
        }
      ),
      [{"Content-Type", "application/json"}]
    )
    {:noreply, webhook_url}
  end
end
