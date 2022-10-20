defmodule GlobalApi.Service.SkinService do
  alias GlobalApi.SkinsRepo
  alias GlobalApi.Utils

  alias GlobalApi.Service.XboxService

  @amount_per_page 60
  @page_limit 10

  @sample_size 100

  @spec recent_uploads(integer | binary) :: {:ok, list, integer, integer} | {:error, {atom, atom}}
  def recent_uploads(page_number) do
    case Utils.get_positive_int(page_number) do
      :error ->
        {:error, {:invalid_page_number, :invalid}}
      {:ok, page_number} ->
        if page_number > @page_limit do
          {:error, {:invalid_page_number, :larger}}
        else
          {:ok, cached} = Cachex.get(:recent_skin_uploads, page_number)
          cached =
            if is_nil(cached) do
              {:ok, result} = Cachex.transaction(:recent_skin_uploads, Enum.to_list(1..@page_limit), fn worker ->
                most_recent = SkinsRepo.get_most_recent_unique(@amount_per_page * @page_limit)

                page_data = Enum.chunk_every(most_recent, @amount_per_page)
                for i <- 1..@page_limit, do: Cachex.put(worker, i, Enum.at(page_data, i - 1))

                Enum.at(page_data, page_number - 1, [])
              end)
              result
            else cached end
          {:ok, cached, @page_limit, page_number}
        end
    end
  end

  @spec popular_bedrock_skins(integer | binary) :: {:ok, list(map), integer, integer} | {:error, {atom, atom}}
  def popular_bedrock_skins(page_number) do
    case Utils.get_positive_int(page_number) do
      :error ->
        {:error, {:invalid_page_number, :invalid}}
      {:ok, page_number} ->
        if page_number > @page_limit do
          {:error, {:invalid_page_number, :larger}}
        else
          {:ok, cached} = Cachex.get(:popular_bedrock_skins, page_number)
          cached =
            if is_nil(cached) do
              {:ok, result} = Cachex.transaction(:popular_bedrock_skins, Enum.to_list(1..@page_limit), fn worker ->
                most_popular = SkinsRepo.most_popular(@amount_per_page * @page_limit)

                # todo store results for their skin id in cachex

                page_data = Enum.chunk_every(most_popular, @amount_per_page)
                for i <- 1..@page_limit, do: Cachex.put(worker, i, Enum.at(page_data, i - 1))

                Enum.at(page_data, page_number - 1, [])
              end)
              result
            else cached end
          {:ok, cached, @page_limit, page_number}
        end
    end
  end

  @spec skin_info(integer | binary) :: map | nil | {:error, {atom, atom}}
  def skin_info(skin_id) do
    case Utils.get_positive_int(skin_id) do
      :error ->
        {:error, {:not_int, :xuid}}

      {:ok, skin_id} ->

        case get_skin_by_id(skin_id) do
          skin when is_map(skin) ->

            case skin_usage_sample(skin_id, @sample_size) do
              sample when is_list(sample) ->

                sample_length = length(sample)

                if sample_length < @sample_size do
                  skin_info_response(skin, sample, sample_length)
                else
                  case skin_usage_count(skin_id) do
                    {:error, _error_type} = response ->
                      response
                    count ->
                      skin_info_response(skin, sample, count || -1)
                  end
                end

              _ = response ->
                # nil or error
                response
            end

          _ = response ->
            # nil or error
            response
        end
    end
  end

  @spec skin_info_with_names(integer | binary) :: map | nil | {:error, {atom, atom}}
  def skin_info_with_names(skin_id) do
    case skin_info(skin_id) do
      {:error, _error_type} = response ->
        response
      nil ->
        nil
      %{sample: sample} = response ->
        case XboxService.gamertag_batch(sample) do
          {:error, _error_type} ->
            # ignore it
            %{response | sample: skin_info_sample_response(sample)}
          {:part, _message, handled, _not_handled} ->
            %{response | sample: skin_info_sample_response(sample, handled)}
          gamertags ->
            %{response | sample: skin_info_sample_response(sample, gamertags)}
        end
    end
  end

  defp skin_info_sample_response(sample, mappings \\ %{}) do
    Enum.map(sample, fn xuid ->
      gamertag = mappings[xuid]
      if is_nil(gamertag) do
        %{id: xuid, name: "#{xuid}*"}
      else
        %{id: xuid, name: gamertag}
      end
    end)
  end

  defp skin_info_response(skin, sample, count) do
    %{
      skin: skin,
      sample: sample,
      count: count
    }
  end

  @spec get_skin_by_xuid(integer | binary) :: map | nil | {:error, {atom, atom}}
  def get_skin_by_xuid(xuid) do
    case Utils.get_positive_int(xuid) do
      :error ->
        {:error, {:not_int, :skin_id}}
      {:ok, xuid} ->
        {_, skin_info} = Cachex.fetch(:xuid_to_skin, xuid, fn xuid ->
          case SkinsRepo.get_player_skin_id(xuid) do
            nil ->
              {:ignore, nil} #todo why don't I cache this?
            {_skin_id, _last_update} = data ->
              {:commit, data}
          end
        end)

        if !is_nil(skin_info) do
          {skin_id, last_update} = skin_info

          result = get_skin_by_id(skin_id)
          if is_map(result) do
            Map.put(result, :last_update, last_update)
          else
            result
          end
        end
    end
  end

  @spec get_skin_by_id(integer | binary) :: map | nil | {:error, {atom, atom}}
  def get_skin_by_id(skin_id) do
    case Utils.get_positive_int(skin_id) do
      :error ->
        {:error, {:not_int, :skin_id}}
      {:ok, skin_id} ->
        {_, skin} = Cachex.fetch(:skin_id_to_skin, skin_id, fn skin_id ->
          case SkinsRepo.get_skin(skin_id) do
            nil ->
              {:ignore, nil} #todo why don't I cache this?
            skin ->
              {
                :commit,
                %{
                  hash: skin.hash,
                  texture_id: skin.texture_id,
                  value: skin.value,
                  signature: skin.signature,
                  is_steve: skin.is_steve
                }
              }
          end
        end)

        skin
    end
  end

  @spec skin_usage_sample(integer | binary, integer) :: list | nil | {:error, {atom, atom}}
  def skin_usage_sample(skin_id, sample_size) when is_integer(sample_size) do
    case Utils.get_positive_int(skin_id) do
      :error ->
        {:error, {:not_int, :skin_id}}
      {:ok, skin_id} ->
        {_, sample} = Cachex.fetch(:skin_usage_sample, skin_id, fn skin_id ->
          case SkinsRepo.get_skin_sample(skin_id, sample_size) do
            nil ->
              {:ignore, nil}
            players ->
              {:commit, players}
          end
        end)

        sample
    end
  end

  @spec skin_usage_count(integer | binary) :: integer | nil| {:error, {atom, atom}}
  def skin_usage_count(skin_id) do
    case Utils.get_positive_int(skin_id) do
      :error ->
        {:error, {:not_int, :skin_id}}
      {:ok, skin_id} ->
        {_, count} = Cachex.fetch(:skin_usage_count, skin_id, fn skin_id ->
          case SkinsRepo.get_skin_usage(skin_id) do
            nil ->
              {:ignore, nil}
            count ->
              {:commit, count}
          end
        end)

        count
    end
  end

  def is_in_bounds(page), do: page >= 1 && page <= @page_limit

  #todo store these in one central module (e.g. Service)
  def error_details({:invalid_page_number, :invalid}), do: {:bad_request, "the page number must be a positive integer"}
  def error_details({:invalid_page_number, :larger}), do: {:bad_request, "the page number must be an integer between 1 and #{@page_limit}"}
  def error_details({:not_int, type}), do: {:bad_request, "#{type} should be an int"}
end
