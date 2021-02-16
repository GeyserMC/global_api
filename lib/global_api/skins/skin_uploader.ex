defmodule GlobalApi.SkinUploader do
  use GenServer

  alias GlobalApi.CustomMetrics
  alias GlobalApi.SocketQueue
  alias GlobalApi.Utils

  @headers [{"Content-Type", "multipart/form-data"}, {"User-Agent", "GeyserMC/GlobalApi"}]

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    {:ok, :ok}
  end

  def send_next(queue, request) do
    GenServer.cast(__MODULE__, {queue, request})
  end

  @impl true
  def handle_cast({queue, request}, :ok) do
    upload_and_store(request, true)
    send queue, :next
    {:noreply, :ok}
  end

  defp upload_and_store({rgba_hash, is_steve, png}, first_try) do
    url = "https://api.mineskin.org/generate/upload?visibility=1" <> get_model_url(is_steve)

    request = HTTPoison.request(
      :post,
      url,
      {
        :multipart,
        [{"file", png, {"form-data", [name: "file", filename: "floodgate-global.png"]}, []}]
      },
      @headers,
      []
    )

    case request do
      {:ok, response} ->
        body = Jason.decode!(response.body)

        error = body["error"]
        if error != nil do
          IO.puts("Error while uploading skin! " <> body["errorCode"] <> " " <> error <> ". First try? #{first_try}")
          if first_try do
            upload_and_store({rgba_hash, is_steve, png}, false)
          end
        else

          next_request = :os.system_time(:millisecond) + (body["nextRequest"] * 1000)

          hash_string = Utils.hash_string(rgba_hash)

          texture_data = body["data"]["texture"]

          texture_id = texture_data["url"]
          # http://textures.minecraft.net/texture/ = 38 chars long
          texture_id = String.slice(texture_id, 38, String.length(texture_id) - 38)

          skin_value = texture_data["value"]
          skin_signature = texture_data["signature"]

          Cachex.put(:hash_to_skin, rgba_hash, {skin_value, skin_signature, texture_id})
          CustomMetrics.add(:skins_uploaded)
          SocketQueue.skin_uploaded(
            rgba_hash,
            %{
              event_id: 3,
              hash: hash_string,
              texture_id: texture_id,
              value: skin_value,
              signature: skin_signature
            }
          )

          next_request = next_request - :os.system_time(:millisecond)
          if next_request > 0 do
            :timer.sleep(next_request)
          end
        end
      {:error, error} ->
        IO.puts("Failed to get a response from the Mineskin server. Reason: " <> error.reason <> ". We'll try it again.")
        upload_and_store({rgba_hash, is_steve, png}, true)
    end
  end

  defp get_model_url(is_steve) do
    if is_steve do
      ""
    else
      "&variant=slim"
    end
  end
end
