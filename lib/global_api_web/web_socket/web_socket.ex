defmodule GlobalApiWeb.WebSocket do
  @behaviour :cowboy_websocket

  alias GlobalApi.SkinNifUtils
  alias GlobalApi.SkinsRepo
  alias GlobalApi.SocketQueue
  alias GlobalApi.UniqueSkin
  alias GlobalApi.Utils

  @invalid_code Jason.encode!(%{error: "invalid code and/or verify code"})
  @code_not_found Jason.encode!(%{error: "failed to find the given code in combination with the verify code"})

  @ping_too_fast Jason.encode!(%{error: "pings have to be at least 10 seconds apart"})
  @invalid_action Jason.encode!(%{error: "invalid action"})
  @invalid_data Jason.encode!(%{error: "invalid data"})

  @invalid_chain_data Jason.encode!(%{error: "invalid chain data"})
  @invalid_client_data Jason.encode!(%{error: "invalid client data"})
  @invalid_skin_size Jason.encode!(%{error: "invalid skin size"})
  @invalid_geometry Jason.encode!(%{error: "invalid geometry"})

  @creator_left Jason.encode!(%{info: "creator left and there are no uploads left"})

  def init(request, _state) do
    opts = %{:idle_timeout => 20000}
    query_map = URI.decode_query(request.qs)

    case Map.fetch(query_map, "subscribed_to") do
      {:ok, subscribed_to} ->
        subscribed_to = Integer.parse(subscribed_to)
        if subscribed_to !== :error do
          {subscribed_to, _} = subscribed_to
          case Map.fetch(query_map, "verify_code") do
            {:ok, verify_code} ->
              {
                :cowboy_websocket,
                request,
                %{
                  subscribed_to: subscribed_to,
                  verify_code: verify_code,
                  is_creator: false,
                  last_ping: 0,
                  initialized: false
                },
                opts
              }
            :error ->
              {:error, @invalid_code}
          end
        else
          {:error, @invalid_code}
        end
      :error ->
        {
          :cowboy_websocket,
          request,
          %{subscribed_to: -1, verify_code: -1, is_creator: true, last_ping: 0, initialized: false},
          opts
        }
    end
  end

  def websocket_init(state) do
    if state.subscribed_to == -1 do
      {id, verify_code} = SocketQueue.create_subscriber(self())
      {
        [{:text, Jason.encode!(%{event_id: 0, id: id, verify_code: verify_code})}],
        %{state | subscribed_to: id, verify_code: verify_code, initialized: true}
      }
    else
      case SocketQueue.add_subscriber(state.subscribed_to, state.verify_code, self()) do
        :error -> {[{:close, @code_not_found}], state}
        pending_uploads ->
          {
            [{:text, Jason.encode!(%{event_id: 0, pending_uploads: pending_uploads})}],
            %{state | initialized: true}
          }
      end
    end
  end

  def websocket_handle(:ping, state) do
    current_time = :os.system_time(:millisecond)
    if current_time - state.last_ping < 10000 do
      {[{:close, @ping_too_fast}], state}
    else
      {:ok, %{state | last_ping: current_time}}
    end
  end

  def websocket_handle(:pong, state) do
    {[{:close, %{error: @invalid_action}}], state}
  end

  def websocket_handle({:ping, _}, state) do
    {[{:close, %{error: @invalid_action}}], state}
  end

  def websocket_handle({:pong, _}, state) do
    {[{:close, %{error: @invalid_action}}], state}
  end

  def websocket_handle({:text, data}, state) when state.is_creator do
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
      case SkinNifUtils.validate_and_get_png(chain_data, client_data) do
        :invalid_chain_data ->
          {[{:close, @invalid_chain_data}], state}
        :invalid_client_data ->
          {[{:close, @invalid_client_data}], state}
        :invalid_size ->
          {[{:close, @invalid_skin_size}], state}
        :invalid_geometry ->
          {[{:close, @invalid_geometry}], state}
        {:invalid_geometry, reason} ->
          {[{:close, Jason.encode!(%{error: "invalid geometry: " <> reason})}], state}
        {xuid, is_steve, png, rgba_hash} ->
          # check for cached skin
          {:ok, entry} = Cachex.get(:xuid_to_skin, xuid)
          if entry != nil do
            # the player's skin is cached, let's go to part 2
            part_two(state, xuid, is_steve, png, rgba_hash, entry)
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
              part_two(state, xuid, is_steve, png, rgba_hash, UniqueSkin.to_protected(player_skin.skin, player_skin))
            else
              part_two(state, xuid, is_steve, png, rgba_hash, %{})
            end
          end
          {:ok, state}
      end
    rescue
      error ->
        IO.inspect("Error: #{inspect(error)}!\n#{inspect(chain_data, limit: :infinity, printable_limit: :infinity)}\n#{inspect(client_data, limit: :infinity, printable_limit: :infinity)}", limit: :infinity, printable_limit: :infinity)
        {:ok, state}
    end
  end

  def websocket_handle({:json, _}, state) do
    {[{:close, 1007, @invalid_data}], state}
  end

  def websocket_handle({:text, _}, state) do
    {[{:close, 1007, @invalid_action}], state}
  end

  defp part_two(state, xuid, is_steve, png, rgba_hash, skin_data) do
    hash = if map_size(skin_data) != 0 do
      skin_data[:hash]
    else
      nil
    end

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

      SocketQueue.broadcast_message(
        state.subscribed_to,
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
            last_update: :os.system_time(:millisecond)
          }
        )
        #todo we can prob also use the return value of set_skin as last_update

        # set skin and return response
        SkinsRepo.set_skin(xuid, skin_id)

        SocketQueue.broadcast_message(
          state.subscribed_to,
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
              last_update: :os.system_time(:millisecond)
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
              last_update: :os.system_time(:millisecond)
            }
          )

          entry = {
            unique_skin.id,
            unique_skin.texture_id,
            unique_skin.value,
            unique_skin.signature
          }
          Cachex.put(:hash_to_skin, {rgba_hash, is_steve}, entry)

          # set the skin and return
          SkinsRepo.set_skin(xuid, unique_skin)

          SocketQueue.broadcast_message(
            state.subscribed_to,
            %{
              event_id: 3,
              xuid: xuid,
              success: true,
              data: UniqueSkin.to_public(unique_skin, %{last_update: :os.system_time(:millisecond)})
            }
          )
        else
          #todo probably check the timestamp as well. When the saved timestamp is higher than the current one, ignore it

          # if the skin isn't cached and isn't in the database then we have to upload it
          SocketQueue.add_pending_upload(state.subscribed_to, xuid, is_steve, png, rgba_hash)
        end
      end
    end
  end

  def websocket_info({:disconnect, :creator_disconnected}, state) do
    [[{:close, 1000, @creator_left}], state]
  end

  def websocket_info({_, data}, state) do
    {[{:text, data}], state}
  end

  def terminate(_reason, _req, state) do
    if state.initialized do
      SocketQueue.remove_subscriber(state.subscribed_to, self(), state.is_creator)
    end
  end
end
