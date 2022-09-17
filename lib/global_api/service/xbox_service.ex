defmodule GlobalApi.Service.XboxService do
  alias GlobalApi.Utils
  alias GlobalApi.XboxApi
  alias GlobalApi.XboxRepo

  def gamertag(xuid) do
    case Utils.get_positive_int(xuid) do
      {:error, _status_code, _message} = response ->
        response
      {:ok, xuid} ->
        {_, response} = Cachex.fetch(
          :get_gamertag,
          xuid,
          fn _ ->
            identity = XboxRepo.get_by_xuid(xuid)
            if identity != nil do
              {:commit, identity.gamertag}
            else
              response = XboxApi.request_gamertag(xuid)
              # save if succeeded
              if is_binary(response) do
                XboxRepo.insert_new(xuid, response)
              end
              {:commit, response}
            end
          end
        )

        response
    end
  end

  def gamertag_batch(xuids) when is_list(xuids) do
    if Enum.count_until(xuids, 601) <= 600 do
      case XboxApi.get_gamertag_batch(xuids) do
        {:ok, data} ->
          data
        {:part, _message, _handled, _not_handled} = response ->
          response
        {:error, _message} = response ->
          response
      end
    else
      {:error, :bad_request, "list has more than 600 elements"}
    end
  end
end
