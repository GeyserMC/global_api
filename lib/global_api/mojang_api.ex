defmodule GlobalApi.MojangApi do
  alias GlobalApi.UUID

  @profile_url "https://sessionserver.mojang.com/session/minecraft/profile/"

  def get_current_username(uuid) do
    response = HTTPoison.get!(@profile_url <> UUID.to_small(uuid))
    json = Jason.decode!(response.body)
    json["name"]
  end
end
