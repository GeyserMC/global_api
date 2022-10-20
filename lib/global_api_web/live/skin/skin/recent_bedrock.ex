defmodule GlobalApiWeb.Skin.RecentBedrock do
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
      description="Most recently uploaded skins"
      {assigns}
    />
    """
  end

  #todo abstract paged pages

  def mount(params, _session, socket) do
    {:ok, load_skins(params["page"] || 1, socket), temporary_assigns: [items: []]}
  end

  def load_skins(current_page, socket) do
    case SkinService.recent_uploads(current_page) do
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
      # Routes.render_path(GlobalApiWeb.Endpoint, :front, item.texture_id)
      %{id: item.id, name: "##{item.id}", img_url: "https://mc-heads.net/player/#{item.texture_id}"}
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
