defmodule GlobalLinkingWeb.SkinController do
  use GlobalLinkingWeb, :controller
  alias GlobalLinking.Repo
  alias GlobalLinking.SkinNifUtils
  alias GlobalLinking.Utils

  def get_skin(conn, %{"xuid" => xuid}) do
    case Utils.is_int_and_rounded(xuid) do
      false ->
        conn
        |> put_status(:bad_request)
        |> json(%{success: false, message: "xuid should be an int"})

      true ->
        {_, result} = Cachex.fetch(:texture_id_by_xuid, xuid, fn _ ->
          case Repo.get_texture_id_by_xuid(xuid) do
            :not_found ->
              {:ignore, :not_found}
            {texture_id, last_update} ->
              {:commit, {texture_id, last_update}}
          end
        end)

        if result === :not_found do
          json(conn, %{success: true, data: %{}})
        else
          {texture_id, last_update} = result
          json(conn, %{success: true, data: %{texture_id: texture_id, last_update: last_update}})
        end
    end
  end

  def post_skin(conn, %{"chainData" => chain_data, "clientData" => client_data, "textureId" => texture_id})
      when is_list(chain_data) and is_binary(client_data) do

    case SkinNifUtils.validate_and_get_hash(chain_data, client_data) do
      :invalid_chain_data ->
        json(conn, %{success: false, message: "Invalid chain data"})
      :invalid_client_data ->
        json(conn, %{success: false, message: "Invalid client data"})
      :invalid_size ->
        json(conn, %{success: false, message: "Invalid skin size"})
      :invalid_geometry ->
        json(conn, %{success: false, message: "The given geometry is not supported"})
      {xuid, username, rgba_hash} ->

        # check for cached skin
        {:ok, value} = Cachex.get(:xuid_request_cache, xuid)
        if value !== :nil do
          json(conn, %{success: true})
        else

          {:ok, hash} = Cachex.get(:texture_id_to_hash, texture_id);

          if hash === :nil do
            case SkinNifUtils.get_texture_compare_hash(rgba_hash, texture_id) do
              {:hash_doesnt_match, texture_hash} ->
                Cachex.put(:texture_id_to_hash, texture_id, texture_hash)
                json(conn, :hash_doesnt_match)
              :ok ->
                Cachex.put(:texture_id_to_hash, texture_id, rgba_hash)
                push_to_db(xuid, texture_id)
                json(conn, :ok)
            end
          else
            # we got another request for this hash, so we keep it longer in cache
            Cachex.put(:texture_id_to_hash, texture_id, hash)
            if rgba_hash === hash do
              push_to_db(xuid, texture_id)
              json(conn, xuid)
            else
              json(conn, :hash_doesnt_match)
            end
          end
        end
    end
  end

  def post_skin(conn, _) do
    json(conn, %{success: false, message: "Arguments chain and/or clientData are missing!"})
  end

  defp push_to_db(xuid, texture_id) do
    MyXQL.query!(:myxql, "INSERT INTO skins (bedrockId, textureId) VALUES ((?), (?)) ON DUPLICATE KEY UPDATE bedrockId = VALUES(bedrockId), textureId = VALUES(textureId)", [xuid, texture_id])
    :ok
  end
end
