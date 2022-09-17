defmodule GlobalApi.SocketManager do
  use GenServer

  alias GlobalApi.DatabaseQueue
  alias GlobalApi.JavaSkinsRepo
  alias GlobalApi.SkinPreQueue
  alias GlobalApi.SkinsRepo
  alias GlobalApi.Utils

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    :ets.new(:skin_uploader_code, [:public, :set, :named_table])
    :ets.new(:skin_uploaders, [:public, :set, :named_table])
    :ets.new(:skin_subscribers, [:public, :bag, :named_table])
    # every skin hash can have multiple uploaders, but every uploader can only be present once per skin
    :ets.new(:skin_pending, [:public, :bag, :named_table])
    :ets.new(:skin_pending_count, [:public, :set, :named_table])
    {:ok, :ok}
  end

  @impl true
  def terminate(reason, state) do
    IO.puts("Socket queue terminates, reason: #{inspect(reason)}")
  end

  @spec create_subscriber(pid) :: {integer, binary}
  def create_subscriber(socket) do
    our_id = :ets.update_counter(:skin_uploader_code, :next_id, 1, {:next_id, -1})
    verify_code = Utils.random_string(10)
    :ets.insert(:skin_uploader_code, {our_id, verify_code})
    :ets.insert(:skin_uploaders, {our_id, socket})
    # the uploader is also a subscriber
    :ets.insert(:skin_subscribers, {our_id, socket})
    {our_id, verify_code}
  end

  @spec add_subscriber(integer, binary, pid) :: true | :not_valid
  def add_subscriber(id, verify_code, socket) do
    if :ets.lookup(:skin_uploader_code, id) == [{id, verify_code}] do
      # we have to include the new subscriber, so +1
      subscribers_count = get_subscribers_count(id) + 1
      broadcast_message(id, %{event_id: 1, subscribers_count: subscribers_count})
      :ets.insert(:skin_subscribers, {id, socket})
    else
      :not_valid
    end
  end

  @spec remove_subscriptions(List.t, pid) :: :ok
  def remove_subscriptions(subscriptions, socket)

  def remove_subscriptions([], _socket), do: :ok

  def remove_subscriptions([id | rest], socket) do
    remove_subscriber(id, socket, false)
    remove_subscriptions(rest, socket)
  end

  @spec remove_subscriber(integer, pid, bool) :: :ok
  def remove_subscriber(id, socket, was_creator)

  def remove_subscriber(id, socket, true) do
    :ets.delete(:skin_uploader_code, id)
    :ets.delete(:skin_uploaders, id)
    # removes the uploader from the subscribers
    :ets.delete_object(:skin_subscribers, {id, socket})

    subscribers = :ets.lookup(:skin_subscribers, id)
    count = length(subscribers)
    pending_uploads = Utils.first(:ets.lookup(:skin_pending_count, id), 0)

    Enum.each(subscribers, fn {_, pid} ->
      send pid, {:creator_disconnected, id}
      # the broadcast method also includes the pending skin count
      send pid, %{
        event_id: 1,
        id: id,
        subscribers_count: count,
        pending_uploads: pending_uploads
      }
      # there is no reason for the subscriber to remain connected if there are no uploads left
      if pending_uploads == 0 do
        send pid, {:creator_disconnected, id}
      end
    end)

    # every subscriber should've received a disconnect message,
    # now all that's left to do is remove all subscribers.
    if pending_uploads == 0 && count > 0 do
      :ets.delete(:skin_subscribers, id)
    end
  end

  def remove_subscriber(id, socket, false) do
    :ets.delete_object(:skin_subscribers, {id, socket})
    subscribers_count = get_subscribers_count(id)
    broadcast_message(id, %{event_id: 1, subscribers_count: subscribers_count})
  end

  @spec skin_upload_failed(binary) :: :ok
  def skin_upload_failed(rgba_hash) do
    #todo look into why we don't store the bool is_steve?
    :ets.take(:skin_pending, rgba_hash)
    |> handle_skin_upload_failed
  end

  def skin_uploaded(rgba_hash, data_map) do
    xuids = :ets.take(:skin_pending, rgba_hash)
      |> handle_skin_uploaded(MapSet.new(), rgba_hash, data_map)

    DatabaseQueue.async_fn_call(fn ->
      skin_id = SkinsRepo.create_or_get_unique_skin(%{data_map | hash: rgba_hash})

      Cachex.put(
        :hash_to_skin,
        {rgba_hash, data_map.is_steve},
        {skin_id, data_map.texture_id, data_map.value, data_map.signature}
      )

      Enum.each(xuids, fn xuid -> SkinsRepo.set_skin(xuid, skin_id) end)
    end, [])
  end

  def add_pending_upload(id, xuid, is_steve, raw_png, rgba_hash, minecraft_hash) do
    is_new_upload = :ets.insert_new(:skin_pending, {rgba_hash, {id, xuid}})
    # the whole 'add pending upload' happens on a single process. Because of that we don't have to make sure that
    # a skin from the same Geyser instance isn't already in the pending count
    :ets.update_counter(:skin_pending_count, id, 1, {id, 0})

    if is_new_upload do
      # we don't have to cache this because this is only called once.
      # after the first try the skin will be in the queue, or the skin will be in the unique skins table
      DatabaseQueue.async_fn_call(fn ->
        minecraft_hash = Utils.hash_string(minecraft_hash)
        skin = JavaSkinsRepo.get_skin(minecraft_hash, is_steve)
        if skin != nil do
          skin_uploaded(
            rgba_hash,
            %{
              hash: Utils.hash_string(rgba_hash),
              texture_id: minecraft_hash,
              value: skin.value,
              signature: skin.signature,
              is_steve: is_steve
            }
          )
        else
          SkinPreQueue.add_request({rgba_hash, is_steve, raw_png})
        end
      end, [])
    end

    broadcast_message(id, %{event_id: 2, xuid: xuid}) # added to queue
  end

  def broadcast_message(id, message, channel \\ :broadcast) do
    message = message
      |> Map.put(:pending_uploads, Utils.first(:ets.lookup(:skin_pending_count, id), 0))
      |> Map.put(:id, id)
      |> Jason.encode!

    :ets.lookup(:skin_subscribers, id)
    |> Enum.each(fn {_, pid} -> send pid, {channel, message} end)
  end

  defp handle_skin_upload_failed([{id, xuid} | tail]) do
    # realistically it's not possible that the id doesn't exist in here,
    # but we also don't want it to lead to unintended behaviour.
    pending_count = :ets.update_counter(:skin_pending_count, id, -1, {id, 1})

    result = Jason.encode!(%{
      event_id: 3,
      id: id,
      pending_uploads: pending_count,
      xuid: xuid,
      success: false
    })
    subscribers = :ets.lookup(:skin_subscribers, id)

    Enum.each(subscribers, fn pid -> send pid, result end)

    if pending_count <= 0 && !:ets.member(:skin_uploaders, id) do
      Enum.each(subscribers, fn pid ->
        send pid, {:creator_disconnected, id}
      end)
      :ets.delete(:skin_subscribers, id)
    end
    handle_skin_upload_failed(tail)
  end

  defp handle_skin_upload_failed([]), do: :ok

  defp handle_skin_uploaded([{id, xuid} | tail], xuids, rgba_hash, data_map) do
    cached = Map.merge(data_map, %{hash: rgba_hash, last_update: :os.system_time(:millisecond)})
    Cachex.put(:xuid_to_skin, xuid, cached)

    # realistically it's not possible that the id doesn't exist in here,
    # but we also don't want it to lead to unintended behaviour.
    pending_count = :ets.update_counter(:skin_pending_count, id, -1, {id, 1})

    result = Jason.encode!(%{
      event_id: 3,
      id: id,
      pending_uploads: pending_count,
      xuid: xuid,
      success: true,
      data: data_map
    })
    subscribers = :ets.lookup(:skin_subscribers, id)

    Enum.each(subscribers, fn pid -> send pid, result end)

    if pending_count <= 0 && !:ets.member(:skin_uploaders, id) do
      Enum.each(subscribers, fn pid ->
        send pid, {:creator_disconnected, id}
      end)
      :ets.delete(:skin_subscribers, id)
    end
    handle_skin_uploaded(tail, MapSet.put(xuids, xuid), rgba_hash, data_map)
  end

  defp handle_skin_uploaded([], xuids, _rgba_hash, _data_map), do: xuids

  def get_subscribers_count(id), do:
    # matches all elements where the first element is the value of id and the tuple arity is 2
    :ets.select_count(:skin_subscribers, [{{id, :_}, [], [true]}])

  def get_pending_upload_count(id), do:
    :ets.lookup(:skin_pending_count, id)
    |> Utils.first(0)
end
