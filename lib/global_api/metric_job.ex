defmodule GlobalApi.MetricJob do
  use GenServer

  alias GlobalApi.MetricsRepo
  alias GlobalApi.SkinPreQueue
  alias GlobalApi.SkinUploadQueue
  alias GlobalApi.DatabaseQueue

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil)
  end

  def init(_) do
    schedule()
    {:ok, {nil, nil, nil, nil}}
  end

  def handle_info(:poll, state) do
    {last_skin_pre_queue_length, last_skin_queue_length, last_db_queue_length, last_db_pool_size} = state

    skin_pre_queue_length = SkinPreQueue.get_queue_length()
    if skin_pre_queue_length != last_skin_pre_queue_length do
      MetricsRepo.set_metric("skin_pre_queue_length", skin_pre_queue_length)
    end

    skin_queue_length = SkinUploadQueue.get_queue_length()
    if skin_queue_length != last_skin_queue_length do
      MetricsRepo.set_metric("skin_queue_length", skin_queue_length)
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
    {:noreply, {skin_pre_queue_length, skin_queue_length, db_queue_length, db_pool_size}}
  end

  defp schedule do
    # 10 seconds
    Process.send_after(self(), :poll, 10 * 1000)
  end
end
