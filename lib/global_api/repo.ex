defmodule GlobalApi.Repo do
  def get_texture_id_by_xuid(xuid) do
    result = MyXQL.query!(:myxql, "SELECT textureId, unix_timestamp(lastUpdate) FROM skins WHERE bedrockId = (?)", [xuid]).rows
    case length(result) do
      0 -> :not_found
      1 ->
        [[texture_id, last_update] | []] = result
        {texture_id, last_update}
    end
  end

  def get_java_link(uuid) do
    result = MyXQL.query!(:myxql, "SELECT bedrockId, javaId, javaName, lastNameUpdate FROM links WHERE javaId = (?)", [uuid]).rows
    format_java_link_result(result, [])
  end

  def get_bedrock_link(xuid) do
    result = MyXQL.query!(:myxql, "SELECT bedrockId, javaId, javaName, lastNameUpdate FROM links WHERE bedrockId = (?)", [xuid]).rows
    case Kernel.length(result) do
      0 -> %{}
      1 ->
        [[bedrockId, javaId, javaName, lastNameUpdate] | []] = result
        %{bedrockId: bedrockId, javaId: javaId, javaName: javaName, lastNameUpdate: lastNameUpdate}
    end
  end

  def update_java_username(uuid, username) do
    currentTime = DateTime.utc_now()
    MyXQL.query!(:myxql, "UPDATE links SET javaName=(?), lastNameUpdate=(?) WHERE javaId=(?)", [username, currentTime, uuid])
    currentTime
  end

  def update_last_name_update(uuid) do
    currentTime = DateTime.utc_now()
    MyXQL.query!(:myxql, "UPDATE links SET lastNameUpdate=(?) WHERE javaId=(?)", [currentTime, uuid])
    currentTime
  end

  defp format_java_link_result([[bedrockId, javaId, javaName, lastNameUpdate] | remaining], result) do
    entry = %{bedrockId: bedrockId, javaId: javaId, javaName: javaName, lastNameUpdate: lastNameUpdate}
    format_java_link_result(remaining, [entry | result])
  end

  defp format_java_link_result([], result) do
    result
  end
end
