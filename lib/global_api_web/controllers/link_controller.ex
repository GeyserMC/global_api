defmodule GlobalApiWeb.LinkController do
  use GlobalApiWeb, :controller

  alias GlobalApi.CustomMetrics
  alias GlobalApi.Repo
  alias GlobalApi.UUID
  alias GlobalApi.Utils

  def get_java_link(conn, %{"uuid" => uuid}) do
    case UUID.cast(uuid) do
      :error ->
        conn
        |> put_status(:bad_request)
        |> json(%{success: false, message: "uuid has to be a valid uuid (36 chars long)"})

      _ ->
        CustomMetrics.add(:get_java_link)

        {_, result} = Cachex.fetch(:java_link, uuid, fn _ ->
          link = Repo.get_java_link(uuid)
          |> Utils.update_username_if_needed_array
          {:commit, link}
        end)

        conn
        |> put_resp_header("cache-control", "max-age=60, s-maxage=60, public")
        |> json(%{success: true, data: result})
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
        CustomMetrics.add(:get_bedrock_link)

        {_, result} = Cachex.fetch(:bedrock_link, xuid, fn _ ->
          link = Repo.get_bedrock_link(xuid)
          |> Utils.update_username_if_needed
          {:commit, link}
        end)

        conn
        |> put_resp_header("cache-control", "max-age=60, s-maxage=60, public")
        |> json(%{success: true, data: result})
    end
  end

  def get_bedrock_link(conn, _) do
    conn
    |> put_status(:bad_request)
    |> put_resp_header("cache-control", "immutable")
    |> json(%{success: false, message: "Please provide a xuid to lookup"})
  end
end
