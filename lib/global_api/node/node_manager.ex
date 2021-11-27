defmodule GlobalApi.Node.NodeManager do
  require Logger
  use GenServer

  alias GlobalApi.SkinUploadQueue
  alias GlobalApi.SocketQueue
  alias GlobalApi.Utils

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: :node_manager)
  end

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @impl true
  def handle_info({:register, node, spawn_module, method, args}, node_map) do
    IO.puts("Node #{node} successfully connected! Spawning a command receiver now.")
    pid = Node.spawn_link(node, spawn_module, method, args)
    node_map = Map.put(node_map, node, pid)
    send_next_skin(node, node_map)
    {:noreply, node_map}
  end

  @impl true
  def handle_info({:deregister, node}, node_map) do
    # prevents new skins from being send to the node
    IO.puts("Received deregister command from #{node}")
    {:noreply, Map.delete(node_map, node)}
  end

  @impl true
  def handle_info({:skin_upload_failed, node, skin_hash, error}, node_map) do
    SocketQueue.skin_upload_failed(skin_hash)
    Sentry.capture_message("Failed to upload skin", extra: %{error: error})
    send_next_skin(node, node_map)
    {:noreply, node_map}
  end

  @impl true
  def handle_info({:skin_uploaded, node, skin_hash, is_steve, first_try, texture_id, skin_value, skin_signature}, node_map) do
    SocketQueue.skin_uploaded(
      skin_hash,
      %{
        hash: Utils.hash_string(skin_hash),
        texture_id: texture_id,
        value: skin_value,
        signature: skin_signature,
        is_steve: is_steve
      }
    )
    :telemetry.execute([:global_api, :metrics, :skins, :skin_uploaded], %{count: 1, first_try: first_try})
    send_next_skin(node, node_map)
    {:noreply, node_map}
  end

  @impl true
  def handle_info(command, node_map) do
    IO.puts("received unknown command from node: #{inspect(command)}")
    {:noreply, node_map}
  end

  defp send_next_skin(node, node_map) do
    command_receiver = node_map[node]
    if command_receiver != nil do
      # the self inside the function will return the upload queue pid
      self = self()
      SkinUploadQueue.get_next_for_node(
        node,
        fn {rgba_hash, is_steve, png} ->
          send command_receiver, {:exec, {:mineskin_upload, rgba_hash, png, is_steve}, self}
        end
      )
    end
  end
end
