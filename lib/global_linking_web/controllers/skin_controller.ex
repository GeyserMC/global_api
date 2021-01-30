defmodule GlobalLinkingWeb.SkinController do
  use GlobalLinkingWeb, :controller
  alias GlobalLinking.SkinUtils
  alias GlobalLinking.SkinNifUtils

  def get_skin(conn, %{"xuid" => xuid}) do

  end

  def post_skin(conn, %{"chain" => chain, "clientData" => client_data})
      when is_list(chain) and is_binary(client_data) do
    case SkinUtils.verify_chain_data(chain) do
      {:ok, last_data, last_key, result} ->
        case SkinUtils.verify_client_data(client_data, last_key) do
          {:ok, jwt} ->
            data = jwt.fields
            geometry = data["SkinResourcePatch"]
            skin_data = data["SkinData"]
            skin_width = data["SkinImageWidth"]
            skin_height = data["SkinImageHeight"]

            username = last_data["ThirdPartyName"]
            xuid = last_data["extraData"]["XUID"]

#            ctm = :os.system_time(:millisecond)
#            result = SkinNifUtils.validate_data(chain, client_data)
#            ctm1 = :os.system_time(:millisecond)
#            IO.puts(ctm1 - ctm)
#
#            png = SkinNifUtils.rgba_to_png(skin_width, skin_height, Base.decode64!(skin_data))
#            digest = :crypto.hash(:sha256, png)
#            |> Base.encode16()
#            IO.puts(digest)

#            {:ok, response} = HTTPoison.request(:post, "https://api.mineskin.org/generate/upload", {:multipart, [{"file", png, {"form-data", [name: "file", filename: "floodgate.png"]}, []}]}, [{"Content-Type", "multipart/form-data"}], [])
#            json(conn, Jason.decode!(response.body))

#            send_download(conn, {:binary, png}, filename: "#{username}.png")
            json(conn, data)
          _ ->
            json(conn, :error)
        end
      _ ->
        json(conn, :error)
    end
  end

  def post_skin(conn, _) do
    json(conn, %{success: false, message: "Arguments chain and/or clientData are missing!"})
  end
end
