defmodule GlobalLinking.SocketQueue do
  use GenServer

  alias GlobalLinking.DatabaseQueue
  alias GlobalLinking.SkinQueue
  alias GlobalLinking.Utils

  @type t :: %__MODULE__{id_subscribers: Map.t(), pending_skins: Map.t(), current_id: integer}

  defstruct id_subscribers: %{}, pending_skins: %{}, current_id: 0

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    {:ok, %__MODULE__{}}
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
        if entry.verify_code === verify_code do
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
  def handle_cast({:skin_uploaded, rgba_hash, data_map}, state) when is_map(data_map) do
    # this is always present, since disconnecting clients will only remove their id_subscribers section and not pending_skins
    requested_by = state.pending_skins[rgba_hash]
    {xuids, state} = handle_skin_uploaded(requested_by.subscribers, MapSet.new(), data_map, state)
    Enum.each(xuids, fn xuid -> DatabaseQueue.set_texture(xuid, data_map.texture_id) end)
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

    if subscriber !== :nil do
      channels = subscriber.channels
      message = Map.put(message, :subscribers_count, Enum.count(channels)) #todo prob remove
      json = Jason.encode!(message)

      Enum.each(
        channels,
        fn socket ->
          send socket, {channel, json}
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

  defp handle_skin_uploaded([{id, xuid} | tail], xuids, data_map, state) do
    case Map.fetch(state.id_subscribers, id) do
      {:ok, entry} ->
        pending_uploads = entry.pending_uploads - 1
        entry = %{entry | pending_uploads: pending_uploads}

        result = Map.put(data_map, :pending_uploads, pending_uploads)
                 |> Map.put(:xuid, xuid)
                 |> Jason.encode!

        Cachex.put(:xuid_to_texture_id, xuid, data_map.texture_id)

        Enum.each(
          entry.channels,
          fn socket ->
            send socket, {:uploaded, result}
          end
        )

        if entry.pending_uploads == 0 do
          broadcast_message(id, :creator_disconnected, :disconnect)
          handle_skin_uploaded(
            tail,
            MapSet.put(xuids, xuid),
            data_map,
            %{state | id_subscribers: Map.delete(state.id_subscribers, id)}
          )
        else
          handle_skin_uploaded(
            tail,
            MapSet.put(xuids, xuid),
            data_map,
            %{state | id_subscribers: Map.put(state.id_subscribers, id, entry)}
          )
        end
      :error ->
        handle_skin_uploaded(tail, MapSet.put(xuids, xuid), data_map, state)
    end
  end

  defp handle_skin_uploaded([], xuids, _data_map, state) do
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
