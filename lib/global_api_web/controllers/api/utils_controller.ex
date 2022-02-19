defmodule GlobalApiWeb.Api.UtilsController do
  use GlobalApiWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GlobalApi.Utils
  alias GlobalApi.UUID
  alias GlobalApi.XboxAccounts
  alias GlobalApi.XboxApi
  alias GlobalApi.XboxRepo
  alias OpenApiSpex.Example
  alias GlobalApiWeb.Schemas

  tags ["utils"]

  operation :get_bedrock_or_java_uuid,
    summary: "Utility endpoint to get either a Java UUID or a Bedrock xuid",
    parameters: [
      username: [in: :path, type: :string, description: "The username of the Minecraft player", examples: %{"bedrock" => %Example{value: ".Tim203"}, "java" => %Example{value: "Tim203"}}],
      prefix: [in: :query, type: :string, description: "The prefix used in your Floodgate config", example: ".", required: true]
    ],
    responses: [
      ok: {"The Bedrock xuid in Floodgate UUID format and username. Response made to be identical to the Mojang endpoint", "application/json", Schemas.UsernameProfile},
      no_content: "Either the gamertag is too long or too short once the prefix was removed or there is no Xbox account registered to the gamertag",
      found: "The player is a Java player and we'll redirect you to the Mojang endpoint for that username",
      bad_request: {"Invalid prefix (no prefix, empty or too long)", "application/json", Schemas.Error},
      service_unavailable: {"The requested account was not cached and we were not able to call the Xbox Live API (rate limited / not setup)", "application/json", Schemas.Error}
    ]

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
                xuid = XboxApi.request_xuid(gamertag)
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
              |> put_status(:service_unavailable)
              |> json(XboxAccounts.not_setup_response())
            {:rate_limit, _} ->
              put_status(conn, :service_unavailable)
              |> json(%{message: "unable to handle request: too much traffic"})
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
      |> json(%{message: "prefix is empty or longer than 16 characters"})
    end
  end

  def get_bedrock_or_java_uuid(conn, _) do
    conn
    |> put_status(:bad_request)
    |> json(%{message: "you have to provide a prefix"})
  end
end
