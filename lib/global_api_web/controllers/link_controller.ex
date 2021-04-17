defmodule GlobalApiWeb.LinkController do
  use GlobalApiWeb, :controller

  alias GlobalApi.Link
  alias GlobalApi.LinksRepo
  alias GlobalApi.UUID
  alias GlobalApi.Utils

  def get_java_link(conn, %{"uuid" => uuid}) do
    case UUID.cast(uuid) do
      :error ->
        conn
        |> put_status(:bad_request)
        |> json(%{success: false, message: "uuid has to be a valid uuid (36 chars long)"})

      _ ->
        {_, link} = Cachex.fetch(:java_link, uuid, fn _ ->
          link = LinksRepo.get_java_link(uuid)
                 |> Utils.update_username_if_needed_array
          {:commit, link}
        end)

        #todo prob. store the raw to_public data instead of caching a Skins obj
        link = Enum.map(link, &Link.to_public/1)

        conn
        |> put_resp_header("cache-control", "max-age=30, public")
        |> json(
             %{
               success: true,
               data: link
             }
           )
    end
  end

  def get_java_link(conn, _) do
    conn
    |> put_status(:bad_request)
    |> put_resp_header("cache-control", "immutable")
    |> json(%{success: false, message: "Please provide an uuid to lookup"})
  end

  def get_bedrock_link(conn, %{"xuid" => xuid}) do
    case Utils.is_int_and_rounded(xuid) do
      false ->
        conn
        |> put_status(:bad_request)
        |> json(%{success: false, message: "xuid should be an int"})

      true ->
        {xuid, _} = Integer.parse(xuid)
        {_, link} = Cachex.fetch(:bedrock_link, xuid, fn _ ->
          link = LinksRepo.get_bedrock_link(xuid)
                 |> Utils.update_username_if_needed
          {:commit, link}
        end)

        conn
        |> put_resp_header("cache-control", "max-age=30, public")
        |> json(
             %{
               success: true,
               data: Link.to_public(link)
             }
           )
    end
  end

  def get_bedrock_link(conn, _) do
    conn
    |> put_status(:bad_request)
    |> put_resp_header("cache-control", "immutable")
    |> json(%{success: false, message: "Please provide a xuid to lookup"})
  end
end
