defmodule GlobalApi.XboxUtils do
  alias GlobalApi.Utils
  alias GlobalApi.XboxApi
  alias GlobalApi.XboxRepo

  def get_gamertag_batch([]), do: {:ok, []}
  def get_gamertag_batch(xuids, map \\ false),
      do: get_gamertag_batch(if map do %{} else [] end, [], xuids, :cache)

  defp get_gamertag_batch(handled, [], [], :cache), do: {:ok, handled}
  defp get_gamertag_batch(handled, not_found, [], :cache),
       do: get_gamertag_batch(handled, not_found, :database)

  defp get_gamertag_batch(handled, not_found, [head | tail], :cache) do
    case Utils.is_int_rounded_and_positive(head) do
      false ->
        {:error, "entries contained an invalid xuid"}
      true ->
        xuid = Utils.get_int_if_string(head)

        {:ok, gamertag} = Cachex.get(:get_gamertag, xuid)
        if is_nil(gamertag) do
          get_gamertag_batch(handled, [xuid | not_found], tail, :cache)
        else
          handled = if is_map(handled),
                       do: Map.put(handled, xuid, gamertag),
                       else: [%{xuid: xuid, gamertag: gamertag} | handled]

          get_gamertag_batch(handled, not_found, tail, :cache)
        end
    end
  end

  defp get_gamertag_batch(handled, to_handle, :database) do
    players_found = XboxRepo.get_by_xuid_bulk(to_handle)
    xuid_to_gamertag = Enum.map(players_found, fn player -> {player.xuid, player.gamertag} end)

    Cachex.put_many(:get_gamertag, xuid_to_gamertag)
    Cachex.put_many(:get_xuid, Enum.map(players_found, fn player -> {player.gamertag, player.xuid} end))

    handled =
      if is_map(handled) do
        Utils.merge_array_to_map(handled, xuid_to_gamertag)
      else
        handled ++ players_found
      end

    to_handle =
      if is_map(handled) do
        Enum.reject(to_handle, fn xuid -> Map.has_key?(handled, xuid) end)
      else
        to_reject = Utils.map_array_to_array(players_found, fn player -> player.xuid end)
        Enum.reject(to_handle, fn xuid -> xuid in to_reject end)
      end

    if length(to_handle) > 0 do
      get_gamertag_batch(handled, to_handle, :request)
    else
      {:ok, handled}
    end
  end

  defp get_gamertag_batch(handled, to_handle, :request) do
    case XboxApi.get_batched(to_handle, false) do
      {:ok, data} ->
        Cachex.put_many(:get_gamertag, data)
        Cachex.put_many(:get_xuid, Enum.map(data, fn {xuid, gamertag} -> {gamertag, xuid} end))

        time = :os.system_time(:millisecond)
        database_data = Enum.map(data, fn {xuid, gamertag} -> [xuid: xuid, gamertag: gamertag, inserted_at: time] end)
        XboxRepo.insert_bulk(database_data)

        data = if is_map(handled),
                  do: Enum.map(data, fn {xuid, gamertag} -> %{xuid => gamertag} end),
                  else: Enum.map(data, fn {xuid, gamertag} -> %{xuid: xuid, gamertag: gamertag} end)

        {:ok, Map.merge(handled, data)}
      {:invalid, xuid} ->
        {:part, "xuid #{inspect(xuid)} doesn't exist", handled, to_handle}
      {:error, _} ->
        {:part, "an unknown error occurred", handled, to_handle}
      {:not_setup} ->
        {
          :part,
          "the global api's xbox api isn't setup correctly, please report this to a GeyserMC administrator",
          handled,
          to_handle
        }
    end
  end
end
