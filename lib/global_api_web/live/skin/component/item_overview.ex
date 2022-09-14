defmodule GlobalApiWeb.Skin.ItemOverview do
  use GlobalApiWeb, :component
  @moduledoc false

  alias GlobalApiWeb.Skin, as: Skin

  def overview(%{type: _, description: _, last_page: _, current_page: _, items: _} = assigns) do
    assigns =
      assigns
      |> assign_new(:first_page, fn -> 1 end)
      |> assign_new(:middle_page, fn -> div(assigns.last_page, 2) end)

    ~H"""
    <header class="bg-white text-gray-900 dark:bg-gray-700 dark:text-gray-200 shadow">
      <div class="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
        <h1 class="text-3xl font-bold text-center">
          <%= @description %>
        </h1>
      </div>
    </header>

    <div class="flex justify-center mt-10 phx-click-loading-child">
      <div class="grid 2xl:grid-cols-7 xl:grid-cols-6 lg:grid-cols-5 md:grid-cols-4 sm:grid-cols-4 grid-cols-2 gap-4 justify-between">
        <%= for item <- @items do %>
          <.overview_item type={@type} socket={@socket} {item} />
        <% end %>
      </div>
    </div>

    <div class="flex w-full justify-center items-center text-gray-800 phx-click-loading-any:bg-gray-500">
      <div class="flex h-10 mt-8 justify-center items-center w-2/4 gap-1.5">
        <.page_button_arrow number={max(@current_page - 1, 1)} arrow_data="M10 19l-7-7m0 0l7-7m-7 7h18" {assigns} />
        <.page_button_number number={@first_page} socket={@socket} />
        <.page_button_number number={@middle_page} socket={@socket} />
        <.page_button_number number={@last_page} socket={@socket} />
        <.page_button_arrow number={min(@current_page + 1, @last_page)} arrow_data="M14 5l7 7m0 0l-7 7m7-7H3" {assigns} />
      </div>
    </div>
    """
  end

  def page_button_number(%{socket: _, number: _} = assigns) do
    ~H"""
    <%=
      live_patch @number,
        to: Routes.live_path(@socket, @socket.view, page: @number),
        class: "px-4 py-2 shadow-md rounded-md dark:text-gray-300 bg-gray-200 dark:bg-gray-700"
    %>
    """
  end

  def page_button_arrow(%{number: _, arrow_data: _, first_page: _, last_page: _} = assigns) do
    ~H"""
    <%=
      live_patch to: Routes.live_path(@socket, @socket.view, page: @number),
        class: "px-4 py-1.5 shadow-md cursor-pointer rounded-md bg-gray-200 dark:bg-gray-700 dark:text-gray-300" do %>
      <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d={@arrow_data} />
      </svg>
    <% end %>
    """
  end

  def overview_item(%{type: _, img_url: _, id: _, name: _} = assigns) do
    ~H"""
    <%=
      live_redirect to: Routes.live_path(@socket, @type, @id),
        class: "flex flex-col items-center justify-center w-32 h-48 md:w-40 md:h-60 mx-auto" do %>
      <div class="w-32 h-48 md:w-40 md:h-60 bg-gray-200 dark:bg-gray-700 rounded-lg flex justify-center items-center shadow-md">
        <img class="w-auto h-4/5 pointer-events-none render-pixelated" src={@img_url} loading="lazy" alt="skin of a player"/>
      </div>
      <div class="w-28 md:w-36 -mt-12 overflow-hidden bg-white rounded-lg dark:bg-gray-800 shadow-lg">
        <div class="py-2 font-semibold tracking-wide text-center text-xs md:text-sm text-gray-800 dark:text-gray-200">
          <%= @name %>
        </div>
      </div>
    <% end %>
    """
  end
end
