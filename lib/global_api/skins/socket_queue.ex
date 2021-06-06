defmodule GlobalApi.SocketQueue do
  use GenServer

  alias GlobalApi.DatabaseQueue
  alias GlobalApi.SkinQueue
  alias GlobalApi.SkinsRepo
  alias GlobalApi.Utils

  @type t :: %__MODULE__{id_subscribers: Map.t(), pending_skins: Map.t(), current_id: integer}

  defstruct id_subscribers: %{}, pending_skins: %{}, current_id: 0

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    {:ok, %__MODULE__{}}
  end

  @impl true
  def terminate(_reason, state) do
    Enum.each(state.id_subscribers, fn subscriber ->
      Enum.each(subscriber.channels, fn channel ->
        send(channel, {:disconnect, :internal_error})
      end)
    end)
  end

  def create_subscriber(socket) do
    GenServer.call(__MODULE__, {:create_subscriber, socket})
  end

  def add_subscriber(id, verify_code, socket) do
    GenServer.call(__MODULE__, {:add_subscriber, id, verify_code, socket})
  end

  def remove_subscriber(id, socket, was_creator) do
    GenServer.cast(__MODULE__, {:remove_subscriber, id, socket, was_creator})
  end

  def skin_upload_failed(rgba_hash) do
    GenServer.cast(__MODULE__, {:skin_upload_failed, rgba_hash})
  end

  def skin_uploaded(rgba_hash, data_to_send) do
    GenServer.cast(__MODULE__, {:skin_uploaded, rgba_hash, data_to_send})
  end

  def add_pending_upload(id, xuid, is_steve, raw_png, rgba_hash) do
    GenServer.cast(__MODULE__, {:add_pending_upload, id, xuid, is_steve, raw_png, rgba_hash})
  end

  def broadcast_message(id, message, channel \\ :broadcast) do
    GenServer.cast(__MODULE__, {:broadcast, id, message, channel})
  end

  @impl true
  def handle_call({:create_subscriber, socket}, _from, state) do
    id = state.current_id
    verify_code = Utils.random_string(8)
    entry = %{verify_code: verify_code, pending_uploads: 0, channels: [socket], is_active: true}
    {
      :reply,
      {id, verify_code},
      %{state | id_subscribers: Map.put(state.id_subscribers, id, entry), current_id: id + 1}
    }
  end

  @impl true
  def handle_call({:add_subscriber, id, verify_code, socket}, _from, state) do
    case Map.fetch(state.id_subscribers, id) do
      {:ok, entry} ->
        if entry.verify_code == verify_code do
          broadcast_message(id, %{event_id: 1, subscribers_count: Enum.count(entry.channels) + 1})
          entry = %{entry | channels: [socket | entry.channels]}
          {
            :reply,
            entry.pending_uploads,
            %{state | id_subscribers: Map.put(state.id_subscribers, id, entry)}
          }
        else
          {:reply, :error, state}
        end
      :error ->
        {:reply, :error, state}
    end
  end

  @impl true
  def handle_cast({:remove_subscriber, id, socket, was_creator}, state) do
    entry = state.id_subscribers[id]
    if entry != nil do
      if was_creator do
        data = Jason.encode!(%{event_id: 4})
        channels = Enum.filter(
          entry.channels,
          fn x ->
            if x !== socket do
              send x, {:creator_disconnected, data}
              true
            end
            false
          end
        )
        broadcast_message(id, %{event_id: 1, subscribers_count: Enum.count(channels)})
        if entry.pending_uploads == 0 do
          broadcast_message(id, :creator_disconnected, :disconnect)
          {:noreply, %{state | id_subscribers: Map.delete(state.id_subscribers, id)}}
        else
          entry = %{entry | is_active: false, channels: channels}
          {:noreply, %{state | id_subscribers: check_empty(state.id_subscribers, id, entry)}}
        end
      else
        channels = Enum.filter(entry.channels, fn x -> x !== socket end)
        broadcast_message(id, %{event_id: 1, subscribers_count: Enum.count(channels)})
        entry = %{entry | channels: channels}
        {:noreply, %{state | id_subscribers: check_empty(state.id_subscribers, id, entry)}}
      end
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:skin_upload_failed, rgba_hash}, state) do
    # this is always present, since disconnecting clients will only remove their id_subscribers section and not pending_skins
    requested_by = state.pending_skins[rgba_hash]
    state = handle_skin_upload_failed(requested_by.subscribers, state)
    {:noreply, %{state | pending_skins: Map.delete(state.pending_skins, rgba_hash)}}
  end

  @impl true
  def handle_cast({:skin_uploaded, rgba_hash, data_map}, state) when is_map(data_map) do
    # this is always present, since disconnecting clients will only remove their id_subscribers section and not pending_skins
    requested_by = state.pending_skins[rgba_hash]
    {xuids, state} = handle_skin_uploaded(requested_by.subscribers, MapSet.new(), rgba_hash, data_map, state)

    DatabaseQueue.async_fn_call(
      fn ->
        skin_id = SkinsRepo.create_or_get_unique_skin(%{data_map | hash: rgba_hash})

        Cachex.put(
          :hash_to_skin,
          {rgba_hash, data_map.is_steve},
          {skin_id, data_map.texture_id, data_map.value, data_map.signature}
        )

        Enum.each(xuids, fn xuid -> SkinsRepo.set_skin(xuid, skin_id) end)
      end,
      []
    )

    {:noreply, %{state | pending_skins: Map.delete(state.pending_skins, rgba_hash)}}
  end

  @impl true
  def handle_cast({:add_pending_upload, id, xuid, is_steve, png, rgba_hash}, state) do
    # key has to exist, because subscribers can't upload skins
    entry = state.id_subscribers[id]
    entry = %{entry | pending_uploads: entry.pending_uploads + 1}

    {is_present, pending_skins} = add_pending_skin(state.pending_skins, rgba_hash, id, xuid)
    state = %{
      state |
      id_subscribers: Map.put(state.id_subscribers, id, entry),
      pending_skins: pending_skins
    }

    if !is_present do
      SkinQueue.add_request({rgba_hash, is_steve, png})
    end

    broadcast_message(id, %{event_id: 2, xuid: xuid}) # added to queue
    {:noreply, state}
  end

  @impl true
  def handle_cast({:broadcast, id, message, channel}, state) do
    # key has to exist, because one of the channels caused this
    subscriber = state.id_subscribers[id]

    if subscriber != nil do
      message = Map.put(message, :pending_uploads, subscriber.pending_uploads)
                |> Jason.encode!

      Enum.each(
        subscriber.channels,
        fn socket ->
          send socket, {channel, message}
        end
      )
    end

    {:noreply, state}
  end

  defp check_empty(subscribers, id, entry) do
    if Enum.count(entry.channels) == 0 do
      Map.delete(subscribers, id)
    else
      Map.put(subscribers, id, entry)
    end
  end

  defp handle_skin_upload_failed([{id, xuid} | tail], state) do
    case Map.fetch(state.id_subscribers, id) do
      {:ok, entry} ->
        pending_uploads = entry.pending_uploads - 1
        entry = %{entry | pending_uploads: pending_uploads}

        result = %{event_id: 3, pending_uploads: pending_uploads, xuid: xuid, success: false}
                 |> Jason.encode!

        Enum.each(
          entry.channels,
          fn socket ->
            send socket, {:uploaded, result}
          end
        )

        if entry.pending_uploads == 0 && !entry.is_active do
          broadcast_message(id, :creator_disconnected, :disconnect)
          handle_skin_upload_failed(
            tail,
            %{state | id_subscribers: Map.delete(state.id_subscribers, id)}
          )
        else
          handle_skin_upload_failed(
            tail,
            %{state | id_subscribers: Map.put(state.id_subscribers, id, entry)}
          )
        end
      :error ->
        handle_skin_upload_failed(tail, state)
    end
  end

  defp handle_skin_upload_failed([], state) do
    state
  end

  defp handle_skin_uploaded([{id, xuid} | tail], xuids, rgba_hash, data_map, state) do
    case Map.fetch(state.id_subscribers, id) do
      {:ok, entry} ->
        pending_uploads = entry.pending_uploads - 1
        entry = %{entry | pending_uploads: pending_uploads}

        result = %{event_id: 3, pending_uploads: pending_uploads, xuid: xuid, success: true, data: data_map}
                 |> Jason.encode!

        cached = Map.merge(data_map, %{hash: rgba_hash, last_update: :os.system_time(:millisecond)})

        Cachex.put(:xuid_to_skin, xuid, cached)

        Enum.each(
          entry.channels,
          fn socket ->
            send socket, {:uploaded, result}
          end
        )

        if entry.pending_uploads == 0 && !entry.is_active do
          broadcast_message(id, :creator_disconnected, :disconnect)
          handle_skin_uploaded(
            tail,
            MapSet.put(xuids, xuid),
            rgba_hash,
            data_map,
            %{state | id_subscribers: Map.delete(state.id_subscribers, id)}
          )
        else
          handle_skin_uploaded(
            tail,
            MapSet.put(xuids, xuid),
            rgba_hash,
            data_map,
            %{state | id_subscribers: Map.put(state.id_subscribers, id, entry)}
          )
        end
      :error ->
        handle_skin_uploaded(tail, MapSet.put(xuids, xuid), rgba_hash, data_map, state)
    end
  end

  defp handle_skin_uploaded([], xuids, _rgba_hash, _data_map, state) do
    {xuids, state}
  end

  defp add_pending_skin(pending_skins, rgba_hash, id, xuid) do
    case Map.fetch(pending_skins, rgba_hash) do
      {:ok, entry} ->
        entry = %{entry | subscribers: [{id, xuid} | entry.subscribers]}
        {true, Map.put(pending_skins, rgba_hash, entry)}
      :error ->
        {false, Map.put(pending_skins, rgba_hash, %{subscribers: [{id, xuid}]})}
    end
  end
end
