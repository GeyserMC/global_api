defmodule GlobalApi.DatabaseQueue do
  use GenServer

  alias GlobalApi.DatabaseUploader

  @type t :: %__MODULE__{
               supervisor: pid,
               queue: List.t(),
               pool_size: Integer,
               uploaders: List.t(),
               uploaders_waiting: List.t()
             }

  defstruct supervisor: nil, queue: :queue.new(), pool_size: 0, uploaders: [], uploaders_waiting: []

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts \\ []) do
    pool_size = Keyword.get(opts, :pool_size)
    {:ok, pid} = DynamicSupervisor.start_link([strategy: :one_for_one])
    uploaders = Enum.map_every(1..pool_size, 1, fn _ -> create_uploader(pid) end)
    {:ok, %__MODULE__{supervisor: pid, pool_size: pool_size, uploaders: uploaders}}
  end

  def async_fn_call(fn_ref, args) do
    GenServer.cast(__MODULE__, {:push, {fn_ref, args}})
  end

  def resume(uploader_pid) do
    send __MODULE__, {:next, uploader_pid}
  end

  def exit(uploader_pid) do
    send __MODULE__, {:exit, uploader_pid}
  end

  def get_queue_length() do
    GenServer.call(__MODULE__, :queue_length)
  end

  @impl true
  def handle_cast({:push, request}, state) do
    if state.uploaders_waiting != [] do
      [uploader_pid | waiting] = state.uploaders_waiting
      state = %{state | uploaders_waiting: waiting}
      send uploader_pid, {:exec, request}
      {:noreply, state}
    else
      {:noreply, %{state | queue: :queue.in(request, state.queue)}}
    end
  end

  @impl true
  @doc """
  Send once one of the DatabaseUploaders is ready to handle another request
  """
  def handle_info({:next, uploader_pid}, state) do
    if :queue.is_empty(state.queue) do
      # this uploader is ready to be used
      waiting = state.uploaders_waiting
      found = Enum.find(waiting, fn pid -> pid == uploader_pid end)
      if found == nil do
        waiting = [uploader_pid | waiting]
        {:noreply, %{state | uploaders_waiting: waiting}}
      else
        {:noreply, state}
      end
    else
      # send next request
      # cannot be :empty since we already did an empty check
      {{:value, result}, queue} = :queue.out(state.queue)
      send uploader_pid, {:exec, result}
      {:noreply, %{state | queue: queue}}
    end
  end

  def handle_info({:exit, uploader_pid}, state) do
    waiting = Enum.reject(state.uploaders_waiting, fn pid -> uploader_pid == pid end)
    uploaders = Enum.reject(state.uploaders, fn pid -> uploader_pid == pid end)

    uploaders =
      if length(state.uploaders) < state.pool_size do
        uploader_pid = create_uploader(self())
        [uploader_pid | uploaders]
      else
        uploaders
      end

    {:noreply, %{state | uploaders: uploaders, uploaders_waiting: waiting}}
  end

  defp create_uploader(supervisor_pid) do
    {:ok, upload_pid} = DynamicSupervisor.start_child(supervisor_pid, {DatabaseUploader, [1]})
    upload_pid
  end

  @impl true
  def handle_call(:queue_length, _, state) do
    # this is not very efficient
    {:reply, :queue.len(state.queue), state}
  end
end
