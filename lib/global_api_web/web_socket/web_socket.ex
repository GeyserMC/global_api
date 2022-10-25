defmodule GlobalApiWeb.WebSocket do
  @behaviour :cowboy_websocket

  alias GlobalApi.SkinsNif
  alias GlobalApi.SkinsRepo
  alias GlobalApi.SocketManager
  alias GlobalApi.UniqueSkin
  alias GlobalApi.Utils
  alias GlobalApi.XboxRepo

  @type t :: %__MODULE__{
    subscriptions: Map.t,
    creator_of: integer | nil,
    last_ping: integer
  }

  defstruct subscriptions: nil, creator_of: nil, last_ping: 0

  @idle_timeout if Mix.env() == :prod, do: 20_000, else: 60 * 60 * 1_000
  @ping_interval 5_000

  @debug -1
  @info 0
  @error 1

  @invalid_code Jason.encode!(%{error: "invalid code and/or verify code"})
  @code_not_found Jason.encode!(%{error: "failed to find the given code in combination with the verify code"})

  @ping_too_fast Jason.encode!(%{error: "pings have to be at least #{ceil(@ping_interval / 1_000)} seconds apart"})
  @invalid_action Jason.encode!(%{error: "invalid action"})
  @invalid_data Jason.encode!(%{error: "invalid data"})

  @invalid_data Jason.encode!(%{error: "invalid chain and/or client data"})

  @creator_left Jason.encode!(%{info: "creator left and there are no uploads left"})
  @internal_error Jason.encode!(%{info: "the service experienced an unexpected error"})

  def init(request, _state) do
    opts = %{:idle_timeout => @idle_timeout, :max_frame_size => 1_572_864} # 1.5mb
    {:cowboy_websocket, request, URI.decode_query(request.qs), opts}
  end

  def websocket_init(query_map) do
    id = query_map["subscribed_to"]
    verify_code = query_map["verify_code"]

    if !is_nil(id) do
      id = Integer.parse(id)
      if id !== :error && !is_nil(verify_code) do
        {id, _} = id
        case SocketManager.add_subscriber(id, verify_code, self()) do
          :not_valid -> {[{:close, @code_not_found}], query_map}
          true ->
            {
              [
                {:text, Jason.encode!(%{
                  event_id: 0,
                  id: id,
                  pending_uploads: SocketManager.get_pending_upload_count(id)
                })}
              ],
              %__MODULE__{subscriptions: [id]}
            }
        end
      else
        {[{:close, @invalid_code}], query_map}
      end
    else
      {id, verify_code} = SocketManager.create_subscriber(self())
      {
        [
          {:text, Jason.encode!(%{event_id: 0, id: id, verify_code: verify_code})}
        ],
        %__MODULE__{subscriptions: [id], creator_of: id}
      }
    end
  end

  def websocket_handle(:ping, state) do
    current_time = System.monotonic_time(:millisecond)
    if (current_time - state.last_ping) < @ping_interval do
      {[{:close, @ping_too_fast}], state}
    else
      {:ok, %{state | last_ping: current_time}}
    end
  end

  def websocket_handle(:pong, state) do
    {[{:close, @invalid_action}], state}
  end

  def websocket_handle({:ping, _}, state) do
    {[{:close, @invalid_action}], state}
  end

  def websocket_handle({:pong, _}, state) do
    {[{:close, @invalid_action}], state}
  end

  def websocket_handle({:text, data}, state) when not is_nil(state.creator_of) do
    case Jason.decode(data) do
      {:ok, json} ->
        websocket_handle({:json, json}, state)
      {:error, _} ->
        {[{:close, 1007, @invalid_data}], state}
    end
  end

  def websocket_handle({:json, %{"chain_data" => chain_data, "client_data" => client_data}}, state)
      when is_list(chain_data) and is_binary(client_data) do
    try do
      case SkinsNif.validate_and_convert(chain_data, client_data) do
        :invalid_data ->
          {[{:close, @invalid_data}], state}

        {:invalid_size, extra_data} ->
          handle_extra_data(extra_data)

          send_log_message(state, @info, "received a skin with an invalid skin size")
          {:ok, state}

        {:invalid_geometry, extra_data} ->
          handle_extra_data(extra_data)

          send_log_message(state, @info, "received a skin with invalid geometry")
          {:ok, state}

        {:invalid_geometry, reason, extra_data} ->
          handle_extra_data(extra_data)

          send_log_message(state, @info, "received a skin with invalid geometry: #{reason}")
          {:ok, state}

        {is_steve, png, rgba_hash, minecraft_hash, {xuid, _, _} = extra_data} ->
          handle_extra_data(extra_data)

          # check for cached skin
          {:ok, entry} = Cachex.get(:xuid_to_skin, xuid)
          if entry != nil do
            # the player's skin is cached, let's go to part 2
            part_two(state, xuid, is_steve, png, rgba_hash, minecraft_hash, entry)
          else
            #todo should probably get the player skin first
            # and when the actual skin isn't cached get the unique_skin
            player_skin = SkinsRepo.get_player_skin(xuid)
            if player_skin != nil do
              unique_skin = player_skin.skin

              entry = {
                unique_skin.id,
                unique_skin.texture_id,
                unique_skin.value,
                unique_skin.signature
              }
              Cachex.put(:hash_to_skin, {unique_skin.hash, unique_skin.is_steve}, entry)

              # the player's skin isn't cached, let's go to part 2
              part_two(state, xuid, is_steve, png, rgba_hash, minecraft_hash, UniqueSkin.to_protected(player_skin.skin, player_skin))
            else
              part_two(state, xuid, is_steve, png, rgba_hash, minecraft_hash, %{})
            end
          end
          {:ok, state}
      end
    rescue
      error ->
        # the client data is too long for Sentry, so we have to be creative
        response = HTTPoison.post!("https://dump.geysermc.org/documents", Jason.encode!(client_data))
        response = Jason.decode!(response.body)

        if is_nil(response[:key]) do
          Sentry.capture_message("Failed to upload dump", extra: %{response: response, exception: error})
        else
          Sentry.capture_exception(error, extra: %{dump_url: response.key})
        end
        {:ok, state}
    end
  end

  def websocket_handle({:json, _}, state) do
    {[{:close, 1007, @invalid_data}], state}
  end

  def websocket_handle({:text, _}, state) do
    {[{:close, 1007, @invalid_action}], state}
  end

  defp handle_extra_data(extra_data) do
    XboxRepo.handle_extra_data(extra_data)
  end

  defp part_two(state, xuid, is_steve, png, rgba_hash, minecraft_hash, skin_data) do
    hash = if map_size(skin_data) != 0, do: skin_data[:hash]

    # since the skin hasn't changed since we last cached it we have to do nothing
    if rgba_hash == hash do
      Cachex.put(
        :xuid_to_skin,
        xuid,
        %{
          hash: skin_data.hash,
          texture_id: skin_data.texture_id,
          value: skin_data.value,
          signature: skin_data.signature,
          is_steve: skin_data.is_steve,
          last_update: skin_data.last_update
        }
      )

      SocketManager.broadcast_message(
        state.creator_of,
        %{
          event_id: 3,
          xuid: xuid,
          success: true,
          data: %{
            skin_data |
            hash: Utils.hash_string(skin_data.hash)
          }
        }
      )
    else
      # if the cached skin of the xuid doesn't match, we'll have to check if the skin itself is cached
      {:ok, entry} = Cachex.get(:hash_to_skin, {rgba_hash, is_steve})

      # skin is already uploaded, but the player doesn't have it
      if entry != nil do
        # apparently this hash is popular, so we'll reset the expire time
        Cachex.put(:hash_to_skin, {rgba_hash, is_steve}, entry)

        {skin_id, texture_id, skin_value, skin_signature} = entry

        Cachex.put(
          :xuid_to_skin,
          xuid,
          %{
            hash: rgba_hash,
            texture_id: texture_id,
            value: skin_value,
            signature: skin_signature,
            is_steve: is_steve,
            last_update: System.system_time(:millisecond)
          }
        )
        #todo we can prob also use the return value of set_skin as last_update

        if hash == nil do
          new_player_notify()
        end

        # set skin and return response
        SkinsRepo.set_skin(xuid, skin_id)

        SocketManager.broadcast_message(
          state.creator_of,
          %{
            event_id: 3,
            xuid: xuid,
            success: true,
            data: %{
              hash: Utils.hash_string(rgba_hash),
              texture_id: texture_id,
              value: skin_value,
              signature: skin_signature,
              is_steve: is_steve,
              last_update: System.system_time(:millisecond)
            }
          }
        )
      else
        # skin isn't cached on the server. Let's ask the database
        unique_skin = SkinsRepo.get_unique_skin(rgba_hash, is_steve)

        # skin is already uploaded, but the player doesn't have it
        if unique_skin != nil do
          Cachex.put(
            :xuid_to_skin,
            xuid,
            %{
              hash: unique_skin.hash,
              texture_id: unique_skin.texture_id,
              value: unique_skin.value,
              signature: unique_skin.signature,
              is_steve: unique_skin.is_steve,
              last_update: System.system_time(:millisecond)
            }
          )

          entry = {
            unique_skin.id,
            unique_skin.texture_id,
            unique_skin.value,
            unique_skin.signature
          }
          Cachex.put(:hash_to_skin, {rgba_hash, is_steve}, entry)

          if hash == nil do
            new_player_notify()
          end

          # set the skin and return
          SkinsRepo.set_skin(xuid, unique_skin)

          SocketManager.broadcast_message(
            state.creator_of,
            %{
              event_id: 3,
              xuid: xuid,
              success: true,
              data: UniqueSkin.to_public(unique_skin, %{last_update: System.system_time(:millisecond)})
            }
          )
        else
          #todo probably check the timestamp as well. When the saved timestamp is higher than the current one, ignore it

          #todo find better solution for this.
          # we don't write to the db instantly (the queue can be hours long),
          # so there is a higher chance for duplicates
          if hash == nil do
            new_player_notify()
          end

          # if the skin isn't cached and isn't in the database then we have to upload it
          SocketManager.add_pending_upload(state.creator_of, xuid, is_steve, png, rgba_hash, minecraft_hash)
        end
      end
    end
  end

  def send_log_message(state, priority, message), do:
    SocketManager.broadcast_message(state.creator_of, %{
      event_id: 5,
      priority: priority,
      message: message
    })

  defp new_player_notify, do:
    :telemetry.execute([:global_api, :metrics, :skins, :new_player], %{count: 1})

  def websocket_info({:creator_disconnected, id}, state) do
    subscriptions = List.delete(state.subscriptions, id)
    state = %{state | subscriptions: subscriptions}

    creator_left_message = {:text, Jason.encode!(%{event_id: 4, id: id})}
    if length(subscriptions) > 0,
       do: {creator_left_message, state},
       else: {[creator_left_message , {:close, 1000, @creator_left}], state}
  end

  def websocket_info({:disconnect, :internal_error}, state), do:
    {[{:close, 1011, @internal_error}], state}

  def websocket_info({_, data}, state), do:
    {[{:text, data}], state}

  def websocket_info(data, state) when is_map(data), do:
    {[{:text, Jason.encode!(data)}], state}

  def websocket_info(data, state), do:
    {[{:text, data}], state}

  def terminate(_reason, _req, state) do
    IO.puts("terminated!")
    subscriptions = Map.get(state, :subscriptions)
    # the creator should always be subscribed to itself
    if !is_nil(subscriptions) do
      Enum.each(subscriptions, fn id ->
        SocketManager.remove_subscriber(id, self(), id == state.creator_of)
      end)
    end
  end
end
