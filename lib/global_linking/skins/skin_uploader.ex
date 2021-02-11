defmodule GlobalLinking.SkinUploader do
  use GenServer

  alias GlobalLinking.CustomMetrics
  alias GlobalLinking.SocketQueue
  alias GlobalLinking.Utils

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
    upload_and_store(request)
    send queue, :next
    {:noreply, :ok}
  end

  defp upload_and_store({rgba_hash, is_steve, png}) do
    url = "https://api.mineskin.org/generate/upload?visibility=1" <> get_model_url(is_steve)

    {:ok, response} = HTTPoison.request(:post, url, {:multipart, [{"file", png, {"form-data", [name: "file", filename: "floodgate-global.png"]}, []}]}, [{"Content-Type", "multipart/form-data"}], [])
    body = Jason.decode!(response.body)

    #todo catch errors and retry

    next_request = :os.system_time(:second) + body["nextRequest"]

    hash_string = Utils.hash_string(rgba_hash)

    texture_id = body["data"]["texture"]["url"]
    # http://textures.minecraft.net/texture/ = 38 chars long
    texture_id = String.slice(texture_id, 38, String.length(texture_id) - 38)

    Cachex.put(:hash_to_texture_id, rgba_hash, texture_id)
    CustomMetrics.add(:skins_uploaded)
    SocketQueue.skin_uploaded(rgba_hash, %{event_id: 3, hash: hash_string, texture_id: texture_id})

    next_request = next_request - :os.system_time(:second)
    if next_request > 0 do
      :timer.sleep(next_request * 1000)
    end
  end

  defp get_model_url(is_steve) do
    if is_steve do "" else "&model=slim" end
  end
end
