defmodule GlobalLinking.SkinChecker do
  use GenServer
  import Phoenix.Controller, only: [json: 2]

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(init_arg) do
    {:ok, :ok}
  end

  def send_next(queue, request) do
    GenServer.cast(__MODULE__, {queue, request})
  end

  @impl true
  def handle_cast({queue, request}, :ok) do
    check(request)
    send queue, :next
    {:noreply, :ok}
  end

  defp check({xuid, username, texture_url, width, height, raw_rgba}) do
    response = HTTPoison.get("https://textures.minecraft.net/texture/#{texture_url}")
    case response do
      {:ok, response} ->
        skin_hash = :crypto.hash(:sha256, raw_rgba)
                    |> Base.encode16()
                    |> String.downcase
        #upload to db
      _ ->
        :ok # handled, but not successfully :(
    end
  end
end
