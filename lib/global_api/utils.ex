defmodule GlobalApi.Utils do
  alias GlobalApi.Link
  alias GlobalApi.LinksRepo
  alias GlobalApi.MojangApi

  def random_string(length) do
    :crypto.strong_rand_bytes(length)
    |> Base.url_encode64
    |> binary_part(0, length)
  end

  def get_env(key, atom) do
    Application.get_env(:global_api, key)[atom]
  end

  def hash_string(hash) do
    hash
    |> Base.encode16
    |> String.downcase
  end

  @doc """
  If the string is in range. Both min and max are inclusive
  """
  def is_in_range(string, min, max) do
    length = String.length(string)
    length >= min && length <= max
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

  def get_int_if_string(data) when is_integer(data) do
    data
  end

  def get_int_if_string(data) when is_binary(data) do
    String.to_integer(data)
  end

  def update_username_if_needed_array(array) do
    update_username_if_needed_array(array, [])
  end

  defp update_username_if_needed_array([], []) do
    []
  end

  #todo make some changes here
  #todo this really needs a revisit

  defp update_username_if_needed_array([current | remaining], []) do
    result = update_username_if_needed(current)
    if result.updated_at == current.updated_at,
       do: [current | remaining], #this is always the first entry, so we should be safe
       else: update_username_if_needed_array(remaining, [result], result.updated_at)
  end

  # if there are no more items to handle, return the result
  defp update_username_if_needed_array([], result, _) do
    result
  end

  defp update_username_if_needed_array([current | remaining], result, time) do
    data = %{current | updated_at: time}
    update_username_if_needed_array(remaining, [data | result], time)
  end

  def update_username_if_needed(%Link{java_id: java_id, java_name: java_name, updated_at: updated_at} = result) do
    time_since_update = :os.system_time(:millisecond) - updated_at
    if time_since_update >= 86_400 * 1000 do # one day
      username = MojangApi.get_current_username(java_id)
      if username != java_name do
        LinksRepo.update_link(result, %{java_name: username})
      else
        # just update the updated_at timestamp
        LinksRepo.update_link(result)
        result
      end
    else
      result
    end
  end

  # no link found
  def update_username_if_needed(result) do
    result
  end
end
