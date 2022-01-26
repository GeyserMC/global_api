defmodule GlobalApi.SkinsNif do
  use Rustler,
      otp_app: :global_api,
      crate: :skins,
      mode: :release

  def validate_and_get_png(_chain_data, _client_data), do: :erlang.nif_error(:nif_not_loaded)
end
