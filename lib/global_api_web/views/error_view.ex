defmodule GlobalApiWeb.ErrorView do
  def render("404.json", _conn) do
    %{success: false, message: "Requested page cannot be found"}
  end

  def render(_, _assigns) do
    %{success: false, message: "Unknown error happened while executing your request"}
  end
end
