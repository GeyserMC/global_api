defmodule GlobalApi.Skins.SkinStorage do
  alias GlobalApi.DatabaseQueue
  alias GlobalApi.Repo
  alias GlobalApi.Schema.SkinStorage, as: Schema

  def store(client_data, convert_code) do
    # Only keep the payload of the JWT
    [_, payload, _] = String.split(client_data, ".")

    # Keep only specific keys, the other keys will only result in storing duplicate data
    final_data =
      payload
      |> Base.url_decode64!(padding: false)
      |> Jason.decode!()
      |> Map.take([
        :SkinResourcePatch,
        :SkinGeometryData,
        :SkinGeometryDataEngineVersion,
        :SkinImageWidth,
        :SkinImageHeight,
        :SkinData,
        :SkinAnimationData,
        :AnimatedImageData,
        :ArmSize,
        :CapeOnClassicSkin,
        :CapeImageWidth,
        :CapeImageHeight,
        :CapeData,
        :PremiumSkin,
        :PersonaSkin
      ])
      |> Jason.encode!()

    identifier = Blake2.hash2b(final_data, 32)

    DatabaseQueue.async_fn_call(fn ->
      Repo.insert(%Schema{hash: identifier, skin: final_data, code: convert_code}, on_conflict: :nothing)
    end, [])
  end
end
