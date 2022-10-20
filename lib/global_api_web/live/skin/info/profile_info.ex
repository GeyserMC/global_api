defmodule GlobalApiWeb.Skin.ProfileInfo do
  use GlobalApiWeb, :live_view

  def render(assigns) do
    ~H"""
    hi profile <%= @id %>!
    """
  end

  def mount(%{"id" => id}, _session, socket) do
    {:ok, assign(socket, :id, id)}
  end
end
