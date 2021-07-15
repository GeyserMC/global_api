defmodule GlobalApiWeb.UtilsController do
  use GlobalApiWeb, :controller

  alias GlobalApi.Utils
  alias GlobalApi.UUID
  alias GlobalApi.XboxApi
  alias GlobalApi.XboxRepo
  alias GlobalApi.XboxUtils

  def get_bedrock_or_java_uuid(conn, %{"prefix" => prefix, "username" => username}) do
    if Utils.is_in_range(prefix, 1, 16) do
      [head | tail] = String.split(username, prefix, parts: 2)

      if head == "" do
        # means that the prefix were the first character(s), so it's a Bedrock username
        [gamertag] = tail
        if Utils.is_in_range(gamertag, 1, 16) do
          {_, xuid} = Cachex.fetch(
            :get_xuid,
            gamertag,
            fn _ ->
              identity = XboxRepo.get_by_gamertag(gamertag)
              if identity != nil do
                {:commit, identity.xuid}
              else
                xuid = XboxApi.get_xuid(gamertag)
                # save if succeeded
                if is_binary(xuid) do
                  XboxRepo.insert_new(xuid, gamertag)
                end
                {:commit, xuid}
              end
            end
          )

          case xuid do
            :not_setup ->
              conn
              |> put_status(:internal_server_error)
              |> json(XboxUtils.not_setup_message())
            {:rate_limit, _} ->
              put_status(conn, :too_many_requests)
            nil ->
              put_status(conn, :no_content)
            xuid ->
              json(conn, %{name: prefix <> gamertag, id: UUID.from_xuid(xuid)})
          end
        else
          put_status(conn, :no_content)
        end

      else
        # if it doesn't start with the prefix, it's a Java player
        redirect(conn, external: "https://api.mojang.com/users/profiles/minecraft/#{username}")
      end
    else
      conn
      |> put_status(:bad_request)
      |> json(%{success: false, message: "prefix is empty or longer than 16 characters"})
    end
  end

  def get_bedrock_or_java_uuid(conn, _),
      do: json(conn, %{success: false, message: "you have to provide a prefix"})
end
