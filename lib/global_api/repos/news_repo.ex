defmodule GlobalApi.NewsRepo do
  alias GlobalApi.NewsItem
  alias GlobalApi.Repo
  import Ecto.Query

  def get_news(project) do
    Repo.all(
      from n in NewsItem,
      where: n.active and n.project == ^project
    )
  end

  def get_all_news() do
    Repo.all(
      from n in NewsItem,
      where: n.active
    )
  end
end
