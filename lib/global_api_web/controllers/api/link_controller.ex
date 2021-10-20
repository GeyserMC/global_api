defmodule GlobalApiWeb.Api.LinkController do
  use GlobalApiWeb, :controller

  alias GlobalApi.Link
  alias GlobalApi.LinksRepo
  alias GlobalApi.MojangApi
  alias GlobalApi.UUID
  alias GlobalApi.Utils
  alias GlobalApi.XboxApi
  alias GlobalApi.XboxAccounts

  def get_java_link(conn, %{"uuid" => uuid}) do
    case UUID.cast(uuid) do
      :error ->
        conn
        |> put_status(:bad_request)
        |> json(%{message: "uuid has to be a valid uuid (36 chars long)"})

      uuid ->
        {_, link} = Cachex.fetch(
          :java_link,
          uuid,
          fn _ ->
            link = LinksRepo.get_java_link(uuid)
                   |> Utils.update_username_if_needed_array
                   |> Enum.map(&Link.to_public/1)
            {:commit, link}
          end
        )

        conn
        |> put_resp_header("cache-control", "max-age=30, public")
        |> json(link)
    end
  end

  def get_java_link(conn, _) do
    conn
    |> put_status(:bad_request)
    |> put_resp_header("cache-control", "immutable")
    |> json(%{message: "please provide an uuid to lookup"})
  end

  def get_bedrock_link(conn, %{"xuid" => xuid}) do
    case Utils.is_int_rounded_and_positive(xuid) do
      false ->
        conn
        |> put_status(:bad_request)
        |> json(%{message: "xuid should be an int"})

      true ->
        {xuid, _} = Integer.parse(xuid)
        {_, link} = Cachex.fetch(
          :bedrock_link,
          xuid,
          fn _ ->
            link = LinksRepo.get_bedrock_link(xuid)
                   |> Utils.update_username_if_needed
                   |> Link.to_public
            {:commit, link}
          end
        )

        conn
        |> put_resp_header("cache-control", "max-age=30, public")
        |> json(link)
    end
  end

  def get_bedrock_link(conn, _) do
    conn
    |> put_status(:bad_request)
    |> put_resp_header("cache-control", "immutable")
    |> json(%{message: "please provide a xuid to lookup"})
  end

  def verify_online_link(conn, %{"bedrock" => bedrock, "java" => java}) do
    if String.length(bedrock) != 16 || String.length(java) != 16 do
      conn
      |> put_status(:bad_request)
      |> put_resp_header("cache-control", "immutable")
      |> json(%{message: "received invalid tokens"})
    else
      # making sure that you can only link a bedrock id with a java id
      bedrock = "bedrock:" <> bedrock
      java = "java:" <> java

      {:ok, bedrock_info} = Cachex.get(:link_token_cache, bedrock)
      {:ok, java_info} = Cachex.get(:link_token_cache, java)

      if bedrock_info == nil || java_info == nil do
        conn
        |> put_status(:bad_request)
        |> json(%{message: "the Java or Bedrock token has expired!"})
      else
        Cachex.expire(:link_token_cache, bedrock, -1)
        Cachex.expire(:link_token_cache, java, -1)
        {xuid, gamertag} = bedrock_info
        {uuid, username} = java_info
        LinksRepo.create_link(xuid, uuid, username)
        json(
          conn,
          %{
            xuid: xuid,
            gamertag: gamertag,
            uuid: uuid,
            username: username
          }
        )
      end
    end
  end

  def verify_online_link(conn, %{"bedrock" => bedrock} = data) do
    case verify_online_link0(bedrock, data["query_info"], true) do
      {:ok, {id, xuid, gamertag}} ->
        json(
          conn,
          %{
            id: id,
            gamertag: gamertag,
            xuid: xuid
          }
        )
      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{message: reason})
    end
  end

  def verify_online_link(conn, %{"java" => java} = data) do
    case verify_online_link0(java, data["query_info"], false) do
      {:ok, {id, uuid, username}} ->
        json(
          conn,
          %{
            success: true,
            data: %{
              id: id,
              username: username,
              uuid: uuid
            }
          }
        )
      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{message: reason})
    end
  end

  def verify_online_link(conn, _) do
    conn
    |> put_status(:bad_request)
    |> put_resp_header("cache-control", "immutable")
    |> json(%{message: "illegal online link data"})
  end

  defp verify_online_link0(token, query_info, is_bedrock) do
    # without query_info our redirect_uri can be incorrect
    if query_info != nil && is_map(query_info) && map_size(query_info) > 2 do
      {:error, "query info is too large!"}
    else
      case parse_query_info(query_info) do
        {:ok, query_info} ->
          case XboxAccounts.start_initial_xbox_setup(token, false, true, query_info, !is_bedrock) do
            {:ok, data} ->
              if is_bedrock do
                {xuid, gamertag} = XboxApi.get_own_profile_info(data.uhs, data.xbox_token)
                {:ok, {generate_random_id({xuid, gamertag}, is_bedrock), xuid, gamertag}}
              else
                access_token = MojangApi.login_with_xbox(data.uhs, data.xbox_token)
                case MojangApi.get_own_profile(access_token) do
                  {:ok, uuid, username} ->
                    {:ok, {generate_random_id({uuid, username}, is_bedrock), uuid, username}}
                  {:error, reason} ->
                    {:error, reason}
                end
              end
            {:error, reason} ->
              {:error, reason}
          end
        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp parse_query_info(query_info) when is_map(query_info) do
    bedrock_token_id = query_info["bedrock"]
    bedrock_info = query_info["b_info"]
    if bedrock_token_id != nil && bedrock_info != nil do
      {:ok, "?bedrock=#{~s(bedrock_token_id)}&b_info=#{bedrock_info}"}
    else
      if bedrock_token_id != nil do
        {:ok, "?bedrock=#{bedrock_token_id}"}
      else
        {:ok, "?b_info=#{bedrock_info}"}
      end
    end
  end

  defp parse_query_info(query_info) when is_nil(query_info), do: {:ok, nil}

  defp parse_query_info(_), do: {:error, "query info isn't a map"}

  defp generate_random_id(data, is_bedrock) do
    random_id = Utils.random_string(16)
    key_name = if is_bedrock do "bedrock:" else "java:" end
    key_name = key_name <> random_id
    # commit is only returned when the fallback has been used,
    # so we can only return when that happens
    case Cachex.fetch(:link_token_cache, key_name, fn _ -> {:commit, data} end) do
      {:commit, _} ->
        random_id
      _ ->
        generate_random_id(data, is_bedrock)
    end
  end
end
