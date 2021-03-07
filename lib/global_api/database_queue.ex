defmodule GlobalApi.DatabaseQueue do
  use GenServer

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    # Setup the database
    MyXQL.query!(:myxql, "
CREATE TABLE IF NOT EXISTS skins
(
    bedrock_id BIGINT NOT NULL,
    hash BINARY(32) NOT NULL,
    texture_id VARCHAR(64) NOT NULL,
    value TEXT NOT NULL,
    signature TEXT NOT NULL,
    is_steve BOOL NOT NULL,
    last_update TIMESTAMP DEFAULT UTC_TIMESTAMP(),
    PRIMARY KEY (bedrock_id),
    INDEX player_skin (bedrock_id, hash, is_steve),
    INDEX unique_skin (hash, is_steve)
);")
    # index bedrock_id,hash,is_steve is used in is_player_using_this

    MyXQL.query!(:myxql, "
CREATE TABLE IF NOT EXISTS links
(
    bedrock_id       BIGINT      NOT NULL,
    java_id          VARCHAR(36) NOT NULL,
    java_name        VARCHAR(16) NOT NULL,
    last_name_update TIMESTAMP DEFAULT UTC_TIMESTAMP(),
    PRIMARY KEY (bedrock_id)
);")

    {:ok, :ok}
  end

  def set_texture(xuid, hash, texture_id, value, signature, is_steve) do
    async_query(
      "INSERT INTO skins (bedrock_id, hash, texture_id, value, signature, is_steve) VALUES ((?), (?), (?), (?), (?), (?))
      ON DUPLICATE KEY UPDATE hash = VALUES(hash), texture_id = VALUES(texture_id), value = VALUES(value), signature = VALUES(signature), is_steve = VALUES(is_steve), last_update = UTC_TIMESTAMP()",
      [xuid, hash, texture_id, value, signature, is_steve]
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
