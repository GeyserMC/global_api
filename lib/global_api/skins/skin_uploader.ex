defmodule GlobalApi.SkinUploader do
  use GenServer

  alias GlobalApi.SkinUploadQueue
  alias GlobalApi.SocketManager
  alias GlobalApi.Utils

  @headers [
    {"Content-Type", "multipart/form-data"},
    {"User-Agent", "GeyserMC/global_api"},
    {"Authorization", Application.get_env(:global_api, :app)[:mineskin_api_key]}
  ]

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    # resume if the uploader has been terminated for whatever reason
    SkinUploadQueue.resume()

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
    try do
      url = "https://api.mineskin.org/generate/upload?visibility=1" <> get_model_url(is_steve)

      request = HTTPoison.request(
        :post,
        url,
        {
          :multipart,
          [{"file", png, {"form-data", [name: "file", filename: "floodgate.png"]}, []}]
        },
        @headers,
        [recv_timeout: 15_000]
      )

      case request do
        {:ok, response} ->
          {resp_type, body} = Jason.decode(response.body)
          # let's handle errors first. For whatever reason cloudflare throws a 502 once in a while
          if resp_type != :ok do
            IO.puts("#{resp_type} #{inspect(body)}")
            upload_and_store({rgba_hash, is_steve, png}, true)
          else
            # yay, data is valid

            error = body["error"]
            if error != nil do
              IO.puts("Error while uploading skin! #{body["errorCode"]} #{error}. First try? #{first_try}")
              IO.puts(inspect(body))

              timeout = ceil((body["nextRequest"] || 0) * 1000) - System.monotonic_time(:millisecond)
              timeout = max(timeout, 0)

              if first_try do
                :timer.sleep(timeout)
                upload_and_store({rgba_hash, is_steve, png}, false)
              else
                SocketManager.skin_upload_failed(rgba_hash)
                :timer.sleep(timeout)
              end
            else
              hash_string = Utils.hash_string(rgba_hash)

              texture_data = body["data"]["texture"]

              texture_id = texture_data["url"]
              # http://textures.minecraft.net/texture/ = 38 chars long
              texture_id = String.slice(texture_id, 38, String.length(texture_id) - 38)

              skin_value = texture_data["value"]
              skin_signature = texture_data["signature"]

              SocketManager.skin_uploaded(
                rgba_hash,
                %{
                  hash: hash_string,
                  texture_id: texture_id,
                  value: skin_value,
                  signature: skin_signature,
                  is_steve: is_steve
                }
              )
              :telemetry.execute([:global_api, :metrics, :skins, :skin_uploaded], %{count: 1, first_try: first_try})

              timeout = ceil((body["nextRequest"] || 0) * 1_000) - System.monotonic_time(:millisecond)
              if timeout > 0 do
                :timer.sleep(timeout)
              end
            end
          end
        {:error, error} ->
          IO.puts("Failed to get a response from the Mineskin server. Reason: " <> inspect(error.reason) <> ". We'll try it again.")
          upload_and_store({rgba_hash, is_steve, png}, true)
      end
    rescue
      e ->
        IO.puts("error! #{inspect(e)}")
        if first_try do
          upload_and_store({rgba_hash, is_steve, png}, false)
        else
          SocketManager.skin_upload_failed(rgba_hash)
        end
    end
  end

  defp get_model_url(true), do: "&variant=classic"
  defp get_model_url(false), do: "&variant=slim"
end
