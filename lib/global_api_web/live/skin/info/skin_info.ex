defmodule GlobalApiWeb.Skin.SkinInfo do
  use GlobalApiWeb, :live_view
  import GlobalApiWeb.Skin.Component.ItemInfo, only: [item_info: 1]

  alias GlobalApi.Service.SkinService
  alias GlobalApiWeb.WrappedError
  alias GlobalApiWeb.NotFoundError

  def render(assigns) do
    ~H"""
    <.item_info
      category="skin"
      count={@count}
      sample={@sample}
      model={@model}
      texture_url={"https://textures.minecraft.net/texture/" <> @texture_id}
      socket={@socket}
    />
    """
  end

  def mount(%{"id" => skin_id}, _session, socket) do
    {:ok, load_skin(skin_id, socket)}
  end

  def load_skin(skin_id, socket) do
    case SkinService.skin_info_with_names(skin_id) do
      {:error, error_type} ->
        raise WrappedError, SkinService.error_details(error_type)
      nil ->
        raise NotFoundError
      info ->
        socket
        |> assign(:count, info.count)
        |> assign(:sample, info.sample)
        |> assign(:model, if info.skin.is_steve do "steve" else "alex" end)
        |> assign(:texture_id, info.skin.texture_id)
    end
  end
end
