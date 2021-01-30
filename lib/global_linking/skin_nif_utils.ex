defmodule GlobalLinking.SkinNifUtils do
  use Rustler, otp_app: :global_linking, crate: "png"

  # When your NIF is loaded, it will override this function.
  def rgba_to_png(_width, _height, _raw_rgba), do: :erlang.nif_error(:nif_not_loaded)

  def validate_data(chain_data, client_data), do: :erlang.nif_error(:nif_not_loaded)
end
