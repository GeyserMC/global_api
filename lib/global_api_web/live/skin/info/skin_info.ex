defmodule GlobalApiWeb.Skin.SkinInfo do
  use GlobalApiWeb, :live_view

  import GlobalApiWeb.Skin.Component.ItemInfo, only: [item_info: 1]

  def render(assigns) do
    ~H"""
    <.item_info
      category="skin"
      count={5}
      sample={[%{id: "12345", name: "Tim203"}]}
      geometry=""
      model="steve"
      texture_url="https://textures.minecraft.net/texture/e29d1acf283b44c77e9b9af7779c173e638a2d63c9b3b3ac0c39f1f8db5d7d9a"
      socket={@socket}
    />
    """
  end

  def mount(%{"id" => skin_id} = params, session, socket) do
    IO.inspect(params)
    IO.inspect(session)
    {:ok, assign(socket, :id, skin_id)}
  end
end
