defmodule GlobalApi.SkinUploadQueue do
  use GenServer

  alias GlobalApi.SkinUploader

  @type t :: %__MODULE__{
               queue: List.t(),
               queue_length: integer,
               nodes_ready: Keyword.t(),
               uploader_ready: bool
             }

  defstruct queue: :queue.new(), queue_length: 0, nodes_ready: [], uploader_ready: true

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

  def resume do
    send __MODULE__, :next
  end

  def queue_length do
    GenServer.call(__MODULE__, :queue_length)
  end

  def get_next_for_node(node, callback) do
    GenServer.cast(__MODULE__, {:next, node, callback})
  end

  @impl true
  def handle_cast({:push, request}, state) do
    if state.uploader_ready do
      state = %{state | uploader_ready: false}
      SkinUploader.send_next(self(), request)
      {:noreply, state}
    else
      if state.nodes_ready != [] do
        [{_node, callback} | nodes_ready] = state.nodes_ready
        callback.(request)
        {:noreply, %{state | nodes_ready: nodes_ready}}
      else
        :telemetry.execute([:global_api, :metrics, :queues, :skin_queue], %{length: state.queue_length + 1})
        {:noreply, %{state | queue: :queue.in(request, state.queue), queue_length: state.queue_length + 1}}
      end
    end
  end

  @impl true
  def handle_cast({:next, node, callback}, state) do
    if state.queue_length == 0 do
      {:noreply, %{state | nodes_ready: Keyword.put(state.nodes_ready, node, callback)}}
    else
      {{:value, result}, queue} = :queue.out(state.queue)
      callback.(result)
      :telemetry.execute([:global_api, :metrics, :queues, :skin_queue], %{length: state.queue_length - 1})
      {:noreply, %{state | queue: queue, queue_length: state.queue_length - 1}}
    end
  end

  @impl true
  @doc """
  Send once the SkinUploader is ready to handle another request
  """
  def handle_info(:next, state) do
    if state.queue_length == 0 do
      :telemetry.execute([:global_api, :metrics, :queues, :skin_queue], %{length: 0})
      {:noreply, %{state | uploader_ready: true}}
    else
      {{:value, result}, queue} = :queue.out(state.queue)
      SkinUploader.send_next(self(), result)
      :telemetry.execute([:global_api, :metrics, :queues, :skin_queue], %{length: state.queue_length - 1})
      {:noreply, %{state | queue: queue, queue_length: state.queue_length - 1}}
    end
  end

  @impl true
  def handle_call(:queue_length, _, state) do
    {:reply, state.queue_length, state}
  end
end
