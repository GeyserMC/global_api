defmodule GlobalApi.Skins.AuthDebugStorage do
  use GenServer

  alias GlobalApi.DatabaseQueue
  alias GlobalApi.Repo
  alias GlobalApi.Schema.AuthDebug, as: Schema

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    :ets.new(:auth_debug_count, [:public, :set, :named_table])
    {:ok, :ok}
  end

  def store(auth_data, client_data) do
    if (:ets.update_counter(:auth_debug_count, :count, 1, {:count, 0}) <= 100) do
      DatabaseQueue.async_fn_call(fn ->
        Repo.insert(%Schema{auth_data: auth_data, client_data: client_data})
      end, [])
    end
  end
end
