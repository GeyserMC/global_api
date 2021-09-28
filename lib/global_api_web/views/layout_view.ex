defmodule GlobalApiWeb.LayoutView do
  use GlobalApiWeb, :view

  #todo we can use locale
  def lang_code(_) do
    "en"
  end

  def link_domain(conn) do
    if Mix.env() == :prod, do: "https://link.geysermc.org", else: "#{conn.scheme}://#{conn.host}:#{conn.port}"
  end

  def skin_domain(conn) do
    if Mix.env() == :prod, do: "https://skin.geysermc.org", else: "#{conn.scheme}://#{conn.host}:#{conn.port}"
  end

  def cdn_domain(conn) do
    # skin domain is temp
    if Mix.env() == :prod, do: "https://skin.geysermc.org", else: "#{conn.scheme}://#{conn.host}:#{conn.port}"
  end
end
