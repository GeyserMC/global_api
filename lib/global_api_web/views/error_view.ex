defmodule GlobalApiWeb.ErrorView do
  use GlobalApiWeb, :view

  def render("404.json", _assigns) do
    %{success: false, message: "Requested page cannot be found"}
  end

  def render(_, _assigns) do
    %{success: false, message: "Unknown error happened while executing your request"}
  end
end
