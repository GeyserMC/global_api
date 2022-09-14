defmodule GlobalApiWeb.Skin.ProfileInfo do
  use GlobalApiWeb, :live_view

  def render(assigns) do
    ~H"""
    hi profile <%= @id %>!
    """
  end

  def mount(%{"id" => skin_id} = params, session, socket) do
    IO.inspect(params)
    IO.inspect(session)
    IO.inspect(socket)
    {:ok, socket}
  end
end
