defmodule GlobalLinking.SkinQueue do
  use GenServer

  alias GlobalLinking.SkinChecker
  alias GlobalLinking.SkinRequest

  @type t :: %__MODULE__{queue: List.t(), checker_ready: bool}

  defstruct queue: [], checker_ready: true

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(init_arg) do
    uploader = Keyword.get(init_arg, :uploader)
    {:ok, %__MODULE__{}}
  end

  def add_request({_, _, _, _, _, _} = data) do
    GenServer.cast(__MODULE__, {:push, data})
  end

  @impl true
  def handle_cast({:push, request}, state) do
    if state.checker_ready do
      state = %{state | checker_ready: false}
      SkinChecker.send_next(self(), request)
      {:noreply, state}
    else
      {:noreply, %{state | queue: [request | state.queue]}}
    end
  end

  @impl true
  @doc """
  Send once the SkinChecker is ready to handle another request
  """
  def handle_info(:next, state) do
    if length(state.queue) == 0 do
      {:noreply, %{state | checker_ready: true}}
    else
      [next | remain] = state.queue
      SkinChecker.send_next(self(), next)
      {:noreply, %{state | queue: remain}}
    end
  end
end
