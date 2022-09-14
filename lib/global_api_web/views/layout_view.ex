defmodule GlobalApiWeb.LayoutView do
  use GlobalApiWeb, :view
  use Phoenix.Component

  # Phoenix LiveDashboard is available only in development by default,
  # so we instruct Elixir to not warn if the dashboard route is missing.
  @compile {:no_warn_undefined, {Routes, :live_dashboard_path, 2}}

  def cdn_domain(), do: get_domain_for(:cdn)
  def link_domain(), do: get_domain_for(:link)
  def skin_domain(), do: get_domain_for(:skin)

  @compile {:inline, get_domain_for: 1}
  def get_domain_for(subdomain) do
    domain_info = Application.get_env(:global_api, :domain_info)
    info = domain_info[subdomain]
    domain_info[:protocol] <> "://" <> info[:subdomain] <> "." <> info[:domain]
  end

  #todo we can use locale
  def lang_code(_), do: "en"

  def menu_items(%{socket: socket}) do
    menu_items(socket.host_uri.host)
  end

  def menu_items(host) do
    case String.split(host, ".", parts: 2) do
      ["link", _] ->
        [
          %{path: "/method/server", text: "Server linking"}
        ]
      ["skin", _] ->
        [
          %{path: "/recent/bedrock", text: "Bedrock most recent", view: Skin.RecentBedrock},
          %{path: "/popular/bedrock", text: "Bedrock most used", view: Skin.PopularBedrock},
          %{path: "/recent/java", text: "Java most recent", view: Skin.RecentJava},
          %{path: "/popular/java", text: "Java most used", view: Skin.PopularJava},
          %{path: "/lookup", text: "Lookup profile", view: Skin.LookupProfile},
        ]
      _ ->
        []
    end
  end
end
