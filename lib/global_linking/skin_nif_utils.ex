defmodule GlobalLinking.SkinNifUtils do
  use Rustler, otp_app: :global_linking, crate: "skins"

  def validate_and_get_hash(chain_data, client_data), do: :erlang.nif_error(:nif_not_loaded)
  def get_texture_compare_hash(rgba_hash, texture_id), do: :erlang.nif_error(:nif_not_loaded)

  def validate_data_and_make_png(chain_data, client_data), do: :erlang.nif_error(:nif_not_loaded)
end
