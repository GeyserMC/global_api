defmodule GlobalApiWeb.LayoutView do
  use GlobalApiWeb, :view

  def link_domain(), do: "https://link.geysermc.org"
  def skin_domain(), do: "https://skin.geysermc.org"
  def cdn_domain(), do: "https://cdn.geysermc.org"

  #todo we can use locale
  def lang_code(_) do
    "en"
  end
end
