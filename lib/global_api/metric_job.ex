defmodule GlobalApi.MetricJob do
  use GenServer

  alias GlobalApi.MetricsRepo
  alias GlobalApi.SkinQueue

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil)
  end

  def init(state) do
    schedule()
    {:ok, state}
  end

  def handle_info(:poll, state) do
    queue_length = SkinQueue.get_queue_length()
    if state == nil || queue_length != state do
      MetricsRepo.set_metric("queue_length", queue_length)
    end

    schedule()
    {:noreply, queue_length}
  end

  defp schedule do
    # 30 seconds
    Process.send_after(self(), :poll, 30 * 1000)
  end
end
