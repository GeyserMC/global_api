defmodule GlobalApi.Skins.SkinStorage do
  alias GlobalApi.DatabaseQueue
  alias GlobalApi.Repo
  alias GlobalApi.Schema.SkinStorage, as: Schema

  def store(client_data, convert_code) do
    # Keep: SkinImageHeight, SkinImageWidth, SkinResourcePatch, SkinGeometryDataEngineVersion, SkinGeometryData, SkinData, SkinAnimationData,
    # PremiumSkin, PersonaSkin, CapeOnClassicSkin, CapeImageWidth, CapeImageHeight, CapeData, ArmSize, AnimatedImageData.
    # The other keys will only result in storing duplicate data
    final_data =
      client_data
      |> Jason.decode!()
      |> Map.drop([
        :CapeId,
        :ClientRandomId,
        :CurrentInputMode,
        :DefaultInputMode,
        :DeviceId,
        :DeviceModel,
        :DeviceOS,
        :GameVersion,
        :GuiScale,
        :IsEditorMode,
        :LanguageCode,
        :PersonaPieces,
        :PieceTintColors,
        :PlatformOfflineId,
        :PlatformOnlineId,
        :PlayFabId,
        :SelfSignedId,
        :ServerAddress,
        :SkinColor,
        :SkinId,
        :ThirdPartyName,
        :ThirdPartyNameOnly,
        :UIProfile
      ])
      |> Jason.encode!()

    identifier = Blake2.hash2b(final_data, 32)

    DatabaseQueue.async_fn_call(fn ->
      Repo.insert(%Schema{hash: identifier, skin: final_data, code: convert_code}, on_conflict: :nothing)
    end)
  end
end
