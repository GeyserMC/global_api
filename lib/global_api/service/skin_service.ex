defmodule GlobalApi.Service.SkinService do
  alias GlobalApi.SkinsRepo
  alias GlobalApi.Utils

  @amount_per_page 60
  @page_limit 10

  @spec recent_uploads(integer | binary) :: {:ok, list, integer, integer} | {:error, integer, binary}
  def recent_uploads(page_number) do
    case Utils.get_positive_int(page_number) do
      :error ->
        {:error, :bad_request, "the page number must be positive integer"}
      {:ok, page_number} ->
        if page_number > @page_limit do
          {:error, :bad_request, "the page number must be an integer between 1 and #{@page_limit}"}
        else
          {:ok, cached} = Cachex.get(:recent_skin_uploads, page_number)
          cached =
            if is_nil(cached) do
              {:ok, result} = Cachex.transaction(:recent_skin_uploads, Enum.to_list(1..@page_limit), fn(worker) ->
                most_recent =
                  SkinsRepo.get_most_recent_unique(@amount_per_page * @page_limit)
                  |> Enum.map(fn {id, texture_id} -> %{id: id, texture_id: texture_id} end)

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
end
