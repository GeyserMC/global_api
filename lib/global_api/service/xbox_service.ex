defmodule GlobalApi.Service.XboxService do
  alias GlobalApi.Utils
  alias GlobalApi.XboxApi
  alias GlobalApi.XboxRepo

  @spec gamertag(integer | binary) :: binary | nil | {:error, {atom, atom}}
  def gamertag(xuid) do
    case Utils.get_positive_int(xuid) do
      :error ->
        {:error, {:not_int, :xuid}}
      {:ok, xuid} ->
        {_, response} = Cachex.fetch(
          :get_gamertag,
          xuid,
          fn ->
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

  @spec gamertag_batch(list(integer | binary)) :: map | {:error, {atom, atom}}
  def gamertag_batch(xuids) when is_list(xuids) do
    if Enum.count_until(xuids, 601) <= 600 do
      case XboxApi.get_gamertag_batch(xuids) do
        {:ok, data} ->
          data
        {:part, _message, _handled, _not_handled} = response ->
          response
        {:error, _error_type} = response ->
          response
      end
    else
      {:error, {:list_too_large, 600}}
    end
  end

  def error_details({:not_int, type}), do: {:bad_request, "#{type} should be an int"}
  def error_details({:list_too_large, limit}), do: {:bad_request, "list has more than #{limit} elements"}
end
