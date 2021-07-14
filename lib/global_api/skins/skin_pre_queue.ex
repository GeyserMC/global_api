defmodule GlobalApi.SkinPreQueue do
  use GenServer

  alias GlobalApi.SkinPreUploader

  @type t :: %__MODULE__{queue: List.t(), queue_length: integer, uploader_ready: bool}

  defstruct queue: :queue.new(), queue_length: 0, uploader_ready: true

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, %__MODULE__{}}
  end

  def add_request({_rgba_hash, _is_steve, _png} = data) do
    GenServer.cast(__MODULE__, {:push, data})
  end

  def resume() do
    send __MODULE__, :next
  end

  @impl true
  def handle_cast({:push, request}, state) do
    if state.uploader_ready do
      state = %{state | uploader_ready: false}
      SkinPreUploader.send_next(self(), request)
      {:noreply, state}
    else
      :telemetry.execute([:global_api, :metrics, :queues, :skin_pre_queue], %{length: state.queue_length + 1})
      {:noreply, %{state | queue: :queue.in(request, state.queue), queue_length: state.queue_length + 1}}
    end
  end

  @impl true
  @doc """
  Send once the SkinPreUploader is ready to handle another request
  """
  def handle_info(:next, state) do
    if state.queue_length == 0 do
      :telemetry.execute([:global_api, :metrics, :queues, :skin_pre_queue], %{length: 0})
      {:noreply, %{state | uploader_ready: true}}
    else
      {{:value, result}, queue} = :queue.out(state.queue)
      SkinPreUploader.send_next(self(), result)
      :telemetry.execute([:global_api, :metrics, :queues, :skin_pre_queue], %{length: state.queue_length - 1})
      {:noreply, %{state | queue: queue, queue_length: state.queue_length - 1}}
    end
  end
end
