defmodule GlobalApiWeb.Skin.PopularBedrock do
  use GlobalApiWeb, :live_view
  import GlobalApiWeb.Skin.ItemOverview

  alias GlobalApi.Service.SkinService

  alias GlobalApiWeb.WrappedError
  alias GlobalApiWeb.Skin.SkinInfo

  @fallback_page 5

  def render(assigns) do
    ~H"""
    <.overview
      type={SkinInfo}
      description="Most popular Bedrock skins"
      {assigns}
    />
    """
  end

  def mount(params, _session, socket) do
    {:ok, load_skins(params["page"] || 1, socket), temporary_assigns: [items: []]}
  end

  def load_skins(current_page, socket) do
    case SkinService.popular_bedrock_skins(current_page) do
      {:error, error_type} ->
        if current_page == @fallback_page do
          raise WrappedError, SkinService.error_details(error_type)
        else
          push_navigate(socket, to: "/?page=#{@fallback_page}")
        end
      {:ok, items, page_limit, current_page} ->
        set_skins(socket, items, page_limit, current_page)
    end
  end

  defp set_skins(socket, items, page_limit, current_page) do
    items = Enum.map(items, fn item ->
      img_path = Routes.render_path(GlobalApiWeb.Endpoint, :front, texture_id: item.texture_id, model: if item.is_steve do "classic" else "slim" end)
      %{id: item.id, name: "##{item.id}", img_url: Router.cdn_host() <> img_path}
    end)

    socket
    |> assign(:current_page, current_page)
    |> assign(:last_page, page_limit)
    |> assign(:items, items)
  end

  def handle_params(params, _url, socket) do
    current_page = params["page"] || 1
    {:noreply, load_skins(current_page, socket)}
  end
end
