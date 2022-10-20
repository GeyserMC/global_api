defmodule GlobalApiWeb.Skin.ItemOverview do
  use GlobalApiWeb, :component
  @moduledoc false

  attr :type, :atom, required: true
  attr :description, :string, required: true
  attr :current_page, :integer, required: true
  attr :first_page, :integer, default: 1
  attr :middle_page, :integer
  attr :last_page, :integer, required: true
  attr :items, :list, required: true

  def overview(assigns) do
    assigns = assign_new(assigns, :middle_page, fn -> div(assigns.last_page, 2) end)
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

  attr :number, :integer, required: true
  attr :socket, :any, required: true

  def page_button_number(assigns) do
    ~H"""
    <.link patch={Routes.live_path(@socket, @socket.view, page: @number)} class="px-4 py-2 shadow-md rounded-md dark:text-gray-300 bg-gray-200 dark:bg-gray-700">
      <%= @number %>
    </.link>
    """
  end

  attr :number, :integer, required: true
  attr :arrow_data, :string, required: true
  attr :socket, :any, required: true

  def page_button_arrow(assigns) do
    ~H"""
    <.link patch={Routes.live_path(@socket, @socket.view, page: @number)} class="px-4 py-1.5 shadow-md cursor-pointer rounded-md bg-gray-200 dark:bg-gray-700 dark:text-gray-300">
      <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d={@arrow_data} />
      </svg>
    </.link>
    """
  end

  attr :type, :atom, required: true
  attr :img_url, :string, required: true
  attr :id, :any, required: true
  attr :name, :string, required: true
  attr :socket, :any, required: true

  def overview_item(assigns) do
    ~H"""
    <.link navigate={Routes.live_path(@socket, @type, @id)} class="flex flex-col items-center justify-center w-32 h-48 md:w-40 md:h-60 mx-auto">
      <div class="w-32 h-48 md:w-40 md:h-60 bg-gray-200 dark:bg-gray-700 rounded-lg flex justify-center items-center shadow-md">
        <img class="w-auto h-4/5 pointer-events-none render-pixelated" src={@img_url} loading="lazy" alt="skin of a player"/>
      </div>
      <div class="w-28 md:w-36 -mt-12 overflow-hidden bg-white rounded-lg dark:bg-gray-800 shadow-lg">
        <div class="py-2 font-semibold tracking-wide text-center text-xs md:text-sm text-gray-800 dark:text-gray-200">
          <%= @name %>
        </div>
      </div>
    </.link>
    """
  end
end
