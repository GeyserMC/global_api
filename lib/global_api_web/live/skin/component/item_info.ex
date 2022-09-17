defmodule GlobalApiWeb.Skin.Component.ItemInfo do
  use GlobalApiWeb, :component

  alias GlobalApiWeb.Skin.ProfileInfo

  def item_info(%{category: _, count: _, sample: _, model: _, texture_url: _, socket: _} = assigns) do
    assigns =
      assigns
      |> assign_new(:geometry, fn -> "" end)

    ~H"""
    <div class="w-full flex justify-center items-center flex-col md:flex-row">
      <div id="left-side" class="w-1/2 flex justify-center items-center">
        <div>
          <%= if assigns[:name] do %>
            <h1 class="text-3xl text-gray-200"><%= @name %></h1>
            <h3 class="text-base text-gray-400">Minecraft <%= String.capitalize(@category) %></h3>
          <% else %>
            <h1 class="text-3xl text-gray-200">Minecraft <%= String.capitalize(@category) %></h1>
          <% end %>
          <h3 class="mt-4 text-gray-300">
            <%= if @count > 0 do %>
            Users with this <%= @category %> (<%= @count %>):
            <% else %>
            There are no users with this <%= @category %> :(
            <% end %>
          </h3>
          <%= for profile <- @sample do %>
            <a href={Routes.live_path(@socket, ProfileInfo, profile.id)}><%= profile.name %></a>
          <% end %>
        </div>
      </div>
      <canvas id="renderTarget" class="transparent order-first md:order-last" style="max-width: 50%"></canvas>
    </div>
    <script>
      window.geometry = "<%= @geometry %>"
      window.model = "<%= @model %>"
      window.texture_url = "https://test.cors.workers.dev/?<%= @texture_url %>"
    </script>
    <script src={Routes.static_url(@socket, "/assets/render.js")}></script>
    """
  end
end
