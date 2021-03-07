defmodule GlobalApi.Utils do
  alias GlobalApi.MojangApi
  alias GlobalApi.Repo

  def random_string(length) do
    :crypto.strong_rand_bytes(length)
    |> Base.url_encode64
    |> binary_part(0, length)
  end

  def get_env(key, atom) do
    Application.get_env(:global_api, key)[atom]
  end

  @doc """
  If the string is in range. Both min and max are inclusive
  """
  def is_in_range(string, min, max) do
    length = String.length(string)
    length >= min && length <= max
  end

  def hash_string(hash) do
    hash
    |> Base.encode16
    |> String.downcase
  end

  def is_int_and_rounded(xuid) do
    case String.contains?(xuid, ".") || String.starts_with?(xuid, "-") do
      true -> false
      false ->
        try do
          Decimal.integer?(xuid)
        rescue
          _ -> false
        end
    end
  end

  def update_username_if_needed_array(array) do
    update_username_if_needed_array(array, [])
  end

  defp update_username_if_needed_array([], []) do
    []
  end

  #todo make some changes here

  defp update_username_if_needed_array([current | remaining], []) do
    result = update_username_if_needed(current)
    if result[:last_name_update] == DateTime.to_unix(current[:last_name_update]),
       do: [result],
       else: update_username_if_needed_array(remaining, [result], result[:last_name_update])
  end

  # if there are no more items to handle, return the result
  defp update_username_if_needed_array([], result, _) do
    result
  end

  defp update_username_if_needed_array([current | remaining], result, time) do
    data = %{current | last_update_time: time}
    update_username_if_needed_array(remaining, [data | result], time)
  end

  def update_username_if_needed(%{java_id: java_id, java_name: java_name, last_name_update: last_name_update} = result) do
    time_since_update = DateTime.diff(DateTime.utc_now(), last_name_update, :second)
    if time_since_update >= 86_400, # one day
       do: (
         username = MojangApi.get_current_username(java_id)
         if username != java_name,
            do: (
              update_time = Repo.update_java_username(java_id, username)
              %{result | java_name: username, last_name_update: DateTime.to_unix(update_time)}
              ),
            else: (
              update_time = Repo.update_last_name_update(java_id)
              %{result | last_name_update: DateTime.to_unix(update_time)}
              )
         ),
       else: %{result | last_name_update: DateTime.to_unix(last_name_update)}
  end

  # no link found
  def update_username_if_needed(result) do
    result
  end
end
