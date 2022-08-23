defmodule GlobalApi.SkinPreUploader do
  use GenServer

  alias GlobalApi.SkinPreQueue
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
    SkinPreQueue.resume()

    {:ok, :ok}
  end

  def send_next(queue, request) do
    GenServer.cast(__MODULE__, {queue, request})
  end

  @impl true
  def handle_cast({queue, request}, :ok) do
    #start_time = :os.system_time(:millisecond)
    upload_and_store(request, true)

    #time_took = :os.system_time(:millisecond) - start_time
    ## Mineskin has two rate-limits, just make sure that we don't spam their server
    #if time_took < 1_000 do
    #  :timer.sleep(1_000 - time_took)
    #end

    send queue, :next
    {:noreply, :ok}
  end

  defp upload_and_store({rgba_hash, is_steve, png}, first_try) do
    #try do
    #  url = "https://api.mineskin.org/generate/upload?checkOnly=true&visibility=1" <> get_model_url(is_steve)

    #  request = HTTPoison.request(
    #    :post,
    #    url,
    #    {
    #      :multipart,
    #      [{"file", png, {"form-data", [name: "file", filename: "floodgate.png"]}, []}]
    #    },
    #    @headers,
    #    [recv_timeout: 15_000]
    #  )

    #  case request do
    #    {:ok, response} ->
    #      {resp_type, body} = Jason.decode(response.body)
    #      # let's handle errors first. For whatever reason cloudflare throws a 502 once in a while
    #      if resp_type != :ok do
    #        IO.puts("#{resp_type} - pre - #{inspect(body)}")
    #        upload_and_store({rgba_hash, is_steve, png}, true)
    #      else
    #        error = body["error"]
    #        if error != nil do
    #          error_code = body["errorCode"]

    #          if error_code != "no_duplicate" do

    #            is_too_many = error == "Too many requests"
    #            if !is_too_many do
    #              IO.puts("Error while checking pre skin! #{body["errorCode"]} #{error}. First try? #{first_try}")
    #              IO.puts(inspect(body))
    #            end

    #            timeout = ceil((body["nextRequest"] || 0) * 1_000) - :os.system_time(:millisecond)
    #            timeout = max(timeout, 1_000)

    #            if is_too_many do
    #              :timer.sleep(timeout)
    #              upload_and_store({rgba_hash, is_steve, png}, first_try)
    #            else
    #              if first_try do
    #                :timer.sleep(timeout)
    #                upload_and_store({rgba_hash, is_steve, png}, false)
    #              else
    #                SocketManager.skin_upload_failed(rgba_hash)
    #                :timer.sleep(timeout)
    #              end
    #            end
    #          else
    #            # no duplicate has been found, we have to pass it to the skin upload queue
                SkinUploadQueue.add_request({rgba_hash, is_steve, png})
    #          end
    #        else
    #          # if the skins has been stored already, we can immediately return it

    #          hash_string = Utils.hash_string(rgba_hash)

    #          texture_data = body["data"]["texture"]

    #          texture_id = texture_data["url"]
    #          # http://textures.minecraft.net/texture/ = 38 chars long
    #          texture_id = String.slice(texture_id, 38, String.length(texture_id) - 38)

    #          skin_value = texture_data["value"]
    #          skin_signature = texture_data["signature"]

    #          SocketManager.skin_uploaded(
    #            rgba_hash,
    #            %{
    #              hash: hash_string,
    #              texture_id: texture_id,
    #              value: skin_value,
    #              signature: skin_signature,
    #              is_steve: is_steve
    #            }
    #          )

    #          timeout = ceil((body["nextRequest"] || 0) * 1000) - :os.system_time(:millisecond)
    #          if timeout > 0 do
    #            :timer.sleep(timeout)
    #          end
    #        end
    #      end
    #    {:error, error} ->
    #      IO.puts("Failed to get a response from the Mineskin server. Reason: " <> inspect(error.reason) <> ". We'll try it again. - pre")
    #      upload_and_store({rgba_hash, is_steve, png}, true)
    #  end
    #rescue
    #  e ->
    #    IO.puts("error! - pre - #{inspect(e)}")
    #    if first_try,
    #      do: upload_and_store({rgba_hash, is_steve, png}, false),
    #      else: SocketManager.skin_upload_failed(rgba_hash)
    #end
  end

  #defp get_model_url(is_steve) do
  #  if is_steve do
  #    "&variant=classic"
  #  else
  #    "&variant=slim"
  #  end
  #end
end
