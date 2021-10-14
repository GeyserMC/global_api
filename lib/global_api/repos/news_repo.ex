defmodule GlobalApi.NewsRepo do
  alias GlobalApi.NewsRepo
  alias GlobalApi.NewsItem
  import Ecto.Query

  def get_news(project) do
    Repo.all(
      from n in NewsItem,
      where: n.active && n.project == ^project
    )
  end

  def get_all_news() do
    Repo.all(
      from n in NewsItem,
      where: n.active
    )
  end
end
