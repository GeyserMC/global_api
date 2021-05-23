defmodule GlobalApi.MojangApi do
  alias GlobalApi.UUID

  @profile_url "https://sessionserver.mojang.com/session/minecraft/profile/"
  @login_with_xbox_url "https://api.minecraftservices.com/authentication/login_with_xbox"
  @own_profile_url "https://api.minecraftservices.com/minecraft/profile"

  def get_current_username(uuid) do
    response = HTTPoison.get!(@profile_url <> UUID.to_small(uuid))
    json = Jason.decode!(response.body)
    json["name"]
  end

  def login_with_xbox(uhs, token) do
    body = Jason.encode!(%{identityToken: "XBL3.0 x=#{uhs};#{token}"})

    response = HTTPoison.post!(@login_with_xbox_url, body, [{"content-type", "application/json"}])
    json = Jason.decode!(response.body)
    json["access_token"]
  end

  def get_own_profile(access_token) do
    response = HTTPoison.get!(@own_profile_url, [{"Authorization", "Bearer #{access_token}"}])
    json = Jason.decode!(response.body)
    if json["error"] != nil do
      {:error, "the given account doesn't own Minecraft Java Edition"}
    else
      {:ok, json["id"], json["name"]}
    end
  end
end
