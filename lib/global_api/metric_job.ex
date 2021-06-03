defmodule GlobalApi.MetricJob do
  use GenServer

  alias GlobalApi.MetricsRepo
  alias GlobalApi.SkinQueue
  alias GlobalApi.DatabaseQueue

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil)
  end

  def init(_) do
    schedule()
    {:ok, {nil, nil, nil}}
  end

  def handle_info(:poll, state) do
    {last_queue_length, last_db_queue_length, last_db_pool_size} = state

    queue_length = SkinQueue.get_queue_length()
    if queue_length != last_queue_length do
      MetricsRepo.set_metric("queue_length", queue_length)
    end

    db_queue_length = DatabaseQueue.get_queue_length()
    if db_queue_length != last_db_queue_length do
      MetricsRepo.set_metric("db_queue_length", db_queue_length)
    end

    db_pool_size = DatabaseQueue.get_pool_size()
    if db_pool_size != last_db_pool_size do
      MetricsRepo.set_metric("db_pool_size", db_pool_size)
    end

    schedule()
    {:noreply, {queue_length, db_queue_length, db_pool_size}}
  end

  defp schedule do
    # 15 seconds
    Process.send_after(self(), :poll, 15 * 1000)
  end
end
