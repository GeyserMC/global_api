defmodule GlobalApi.SkinsNif do
  use Rustler,
      otp_app: :global_api,
      crate: :skins,
      mode: :release

  @type extra_data() :: {binary, binary, integer}

  @spec validate_and_convert(list, binary) ::
    :invalid_data |
    {:invalid_size | :invalid_geometry, extra_data()} |
    {:invalid_geometry, binary, extra_data()} |
    {boolean, binary, binary, binary, extra_data()}
  def validate_and_convert(_chain_data, _client_data) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @spec render_skin_front(binary, :bottom | :top | :both, :classic | :slim, integer) :: :invalid_image | binary
  def render_skin_front(_data, _layer, _model, _target_width) do
    :erlang.nif_error(:nif_not_loaded)
  end
end
