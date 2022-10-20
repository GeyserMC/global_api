defmodule GlobalApiWeb.Cdn.RenderController do
  use GlobalApiWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GlobalApi.SkinsNif
  alias GlobalApi.Utils

  tags ["skin", "render"]

  def front(conn, %{"texture_id" => texture_id, "model" => model}) do
    case model_to_atom(model) do
      :invalid ->
        conn
        |> put_status(:bad_request)
        |> put_resp_header("cache-control", "max-age=86400, immutable, public")
        |> json(%{message: "invalid model"})
      model ->
        if Utils.is_hexadecimal(texture_id) do
          #todo store the skins
          body = HTTPoison.get!("https://textures.minecraft.net/texture/#{texture_id}").body
          case Jason.decode(body) do
            {:ok, _} ->
              conn
              |> put_status(:bad_gateway)
              |> put_resp_header("cache-control", "max-age=30, public")
              |> json(%{message: "expected image from Minecraft, got json"})
            {:error, _} ->
              #todo impl scale
              case SkinsNif.render_skin_front(body, :both, model, 16) do
                :invalid_image ->
                  conn
                  |> put_status(:bad_gateway)
                  |> put_resp_header("cache-control", "max-age=30, public")
                  |> json(%{message: "expected valid image from Minecraft"})
                render ->
                  conn
                  |> put_resp_header("cache-control", "max-age=86400, immutable, public")
                  |> send_download({:binary, render}, filename: "#{texture_id}.png")
              end
          end

        else
          conn
          |> put_status(:bad_request)
          |> put_resp_header("cache-control", "max-age=86400, immutable, public")
          |> json(%{message: "invalid texture_id"})
        end
    end
  end

  def raw(conn, %{"texture_id" => texture_id}) do
    if Utils.is_hexadecimal(texture_id) do
      #todo store the skins
      body = HTTPoison.get!("https://textures.minecraft.net/texture/#{texture_id}").body
      case Jason.decode(body) do
        {:ok, _} ->
          conn
          |> put_status(:bad_gateway)
          |> put_resp_header("cache-control", "max-age=30, public")
          |> json(%{message: "expected image from Minecraft, got json"})
        {:error, _} ->
          conn
          |> put_resp_header("cache-control", "max-age=86400, immutable, public")
          |> send_download({:binary, body}, filename: "#{texture_id}.png")
      end
    else
      conn
      |> put_status(:bad_request)
      |> put_resp_header("cache-control", "max-age=86400, immutable, public")
      |> json(%{message: "invalid texture_id"})
    end
  end

  defp fetch_texture(texture_id) do

  end

  @spec model_to_atom(binary) :: :classic | :slim | :invalid
  defp model_to_atom(model) do
    case model do
      "classic" -> :classic
      "slim" -> :slim
      _ -> :invalid
    end
  end
end
