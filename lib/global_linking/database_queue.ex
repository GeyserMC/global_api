defmodule GlobalLinking.DatabaseQueue do
  use GenServer

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    {:ok, :ok}
  end

  def set_texture(xuid, texture_id) do
    async_query(
      "INSERT INTO skins (bedrockId, textureId) VALUES ((?), (?)) ON DUPLICATE KEY UPDATE bedrockId = VALUES(bedrockId), textureId = VALUES(textureId), lastUpdate = UTC_TIMESTAMP()",
      [xuid, texture_id]
    )
  end

  def async_query(iodata, list) do
    GenServer.cast(__MODULE__, {:async_query, iodata, list})
  end

  @impl true
  def handle_cast({:async_query, iodata, list}, state) do
    MyXQL.query(:myxql, iodata, list)
    {:noreply, state}
  end
end
