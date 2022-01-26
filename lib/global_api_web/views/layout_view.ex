defmodule GlobalApiWeb.LayoutView do
  use GlobalApiWeb, :view

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
end
