defmodule GlobalLinking.CustomMetrics do
  use GenServer

  @type t :: %__MODULE__{
               subscribers_created: integer, # websocket related
               subscribers_added: integer,
               subscribers_removed: integer,
               skins_uploaded: integer,
               skin_upload_requests: integer,
               get_xuid: integer, # xbox controller
               get_gamertag: integer,
               get_java_link: integer, # link controller
               get_bedrock_link: integer
             }

  defstruct subscribers_created: 0,
            subscribers_added: 0,
            subscribers_removed: 0,
            skins_uploaded: 0,
            skin_upload_requests: 0,
            get_xuid: 0,
            get_gamertag: 0,
            get_java_link: 0,
            get_bedrock_link: 0

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    {:ok, %__MODULE__{}}
  end

  def add(channel, amount \\ 1) do
    GenServer.cast(__MODULE__, {:add, channel, amount})
  end

  def fetch_all() do
    GenServer.call(__MODULE__, :fetch_all)
  end

  @impl true
  def handle_cast({:add, channel, amount}, state) do
    case state do
      %{^channel => value} ->
        if value !== nil do
          {:noreply, Map.put(state, channel, value + amount)}
        else
          {:noreply, state}
        end
    end
  end

  @impl true
  def handle_call(:fetch_all, _from, state) do
    {:reply, state, %__MODULE__{}}
  end
end
