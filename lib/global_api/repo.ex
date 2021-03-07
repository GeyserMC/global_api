defmodule GlobalApi.Repo do
  alias GlobalApi.Utils

  def get_skin_by_xuid(xuid) do
    result = MyXQL.query!(
      :myxql,
      "SELECT hash, texture_id, value, signature, is_steve, unix_timestamp(last_update) FROM skins WHERE bedrock_id = (?)",
      [xuid]
    ).rows
    case length(result) do
      0 -> :not_found
      1 ->
        [[hash, texture_id, value, signature, is_steve, last_update] | []] = result
        # binary is a bit too raw, we stringify it instead
        {Utils.hash_string(hash), texture_id, value, signature, is_steve, last_update}
    end
  end

  def get_player_or_skin(xuid, hash, is_steve) when is_binary(hash) do
    result = MyXQL.query!(
      :myxql,
      "SELECT bedrock_id, texture_id, value, signature, unix_timestamp(last_update) FROM skins WHERE hash = (?) AND is_steve = (?) ORDER BY (bedrock_id=(?)) DESC LIMIT 1",
      [hash, is_steve, xuid]
    ).rows
    case length(result) do
      0 -> :not_found
      1 ->
        [[bedrock_id, texture_id, value, signature, last_update] | []] = result
        {bedrock_id, texture_id, value, signature, last_update}
    end
  end

  def is_player_using_this(xuid, hash, is_steve) when is_binary(hash) do
    [[is_used]] = MyXQL.query!(
                  :myxql,
                  "SELECT COUNT(*) FROM skins WHERE bedrock_id = (?) AND hash = (?) AND is_steve = (?)",
                  [xuid, hash, is_steve]
                ).rows
    is_used > 0
  end

  def get_uploaded_skin(hash, is_steve) when is_binary(hash) do
    result = MyXQL.query!(
      :myxql,
      "SELECT texture_id, value, signature FROM skins WHERE hash = (?) AND is_steve = (?) LIMIT 1",
      [hash, is_steve]
    ).rows
    case length(result) do
      0 -> :not_found
      1 ->
        [[texture_id, value, signature] | []] = result
        {texture_id, value, signature}
    end
  end

  def get_players_with_skin(hash, is_steve) when is_binary(hash) and is_boolean(is_steve) do
    result = MyXQL.query!(
      :myxql,
      "SELECT bedrock_id, unix_timestamp(last_update) FROM skins WHERE hash = (?) AND is_steve = (?)",
      [hash, is_steve]
    ).rows
    format_get_players_with_skin(result, [])
  end

  def get_java_link(uuid) do
    result = MyXQL.query!(
      :myxql,
      "SELECT bedrock_id, java_id, java_name, last_name_update FROM links WHERE java_id = (?)",
      [uuid]
    ).rows
    format_java_link(result, [])
  end

  def get_bedrock_link(xuid) do
    result = MyXQL.query!(
      :myxql,
      "SELECT bedrock_id, java_id, java_name, last_name_update FROM links WHERE bedrock_id = (?)",
      [xuid]
    ).rows
    case Kernel.length(result) do
      0 -> %{}
      1 ->
        [[bedrock_id, java_id, java_name, last_name_update] | []] = result
        %{bedrock_id: bedrock_id, java_id: java_id, java_name: java_name, last_name_update: last_name_update}
    end
  end

  def update_java_username(uuid, username) do
    current_time = DateTime.utc_now()
    MyXQL.query!(
      :myxql,
      "UPDATE links SET java_name=(?), last_name_update=(?) WHERE java_id=(?)",
      [username, current_time, uuid]
    )
    current_time
  end

  def update_last_name_update(uuid) do
    current_time = DateTime.utc_now()
    MyXQL.query!(:myxql, "UPDATE links SET last_name_update=(?) WHERE java_id=(?)", [current_time, uuid])
    current_time
  end

  defp format_get_players_with_skin([[bedrock_id, last_update] | remaining], result) do
    entry = {bedrock_id, last_update}
    format_get_players_with_skin(remaining, [entry | result])
  end

  defp format_get_players_with_skin([], result), do: result

  defp format_java_link([[bedrock_id, java_id, java_name, last_name_update] | remaining], result) do
    entry = %{bedrock_id: bedrock_id, java_id: java_id, java_name: java_name, last_name_update: last_name_update}
    format_java_link(remaining, [entry | result])
  end

  defp format_java_link([], result), do: result
end
