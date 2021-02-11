defmodule GlobalLinkingWeb.WebSocket do
  @behaviour :cowboy_websocket

  alias GlobalLinking.CustomMetrics
  alias GlobalLinking.DatabaseQueue
  alias GlobalLinking.SkinNifUtils
  alias GlobalLinking.SocketQueue
  alias GlobalLinking.Utils

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
      CustomMetrics.add(:subscribers_created)
      {id, verify_code} = SocketQueue.create_subscriber(self())
      {
        [{:text, Jason.encode!(%{event_id: 0, id: id, verify_code: verify_code})}],
        %{state | subscribed_to: id, verify_code: verify_code, initialized: true}
      }
    else
      CustomMetrics.add(:subscribers_added)
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
    case SkinNifUtils.validate_and_get_png(chain_data, client_data) do
      :invalid_chain_data ->
        {[{:close, @invalid_chain_data}], state}
      :invalid_client_data ->
        {[{:close, @invalid_client_data}], state}
      :invalid_size ->
        {[{:close, @invalid_skin_size}], state}
      :invalid_geometry ->
        {[{:close, @invalid_geometry}], state}
      {xuid, is_steve, png, rgba_hash} ->
        #todo validate xuid maybe?

        CustomMetrics.add(:skin_upload_requests)

        # check for cached skin
        {:ok, texture_id} = Cachex.get(:xuid_to_texture_id, xuid)
        if texture_id !== :nil do
          SocketQueue.broadcast_message(
            state.subscribed_to,
            %{event_id: 3, xuid: xuid, texture_id: texture_id, hash: Utils.hash_string(rgba_hash)}
          )
          {:ok, state}
        else

          {:ok, texture_id} = Cachex.get(:hash_to_texture_id, rgba_hash);

          if texture_id === :nil do
            SocketQueue.add_pending_upload(state.subscribed_to, xuid, is_steve, png, rgba_hash)
            {:ok, state}
          else
            Cachex.put(:xuid_to_texture_id, xuid, texture_id)

            # apparently this hash is popular, so we'll reset the expire time
            Cachex.put(:hash_to_texture_id, rgba_hash, texture_id)

            DatabaseQueue.set_texture(xuid, texture_id)
            SocketQueue.broadcast_message(
              state.subscribed_to,
              %{event_id: 3, xuid: xuid, texture_id: texture_id}
            )
          end
        end
    end
  end

  def websocket_handle({:json, _}, state) do
    {[{:close, 1007, @invalid_data}], state}
  end

  def websocket_handle({:text, _}, state) do
    {[{:close, 1007, @invalid_action}], state}
  end

  def websocket_info({:disconnect, :creator_disconnected}, state) do
    [[{:close, 1000, @creator_left}], state]
  end

  def websocket_info({_, data}, state) do
    {[{:text, data}], state}
  end

  def terminate(_reason, _req, state) do
    if state.initialized do
      CustomMetrics.add(:subscribers_removed)
      SocketQueue.remove_subscriber(state.subscribed_to, self(), state.is_creator)
    end
  end
end
