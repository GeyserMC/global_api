defmodule GlobalApi.JavaSkinsRepo do
  alias GlobalApi.Repo
  alias GlobalApi.JavaSkin
  import Ecto.Query

  def get_skin(texture_id, is_steve) do
    Repo.one(from s in JavaSkin, where: s.id == ^texture_id and s.is_steve == ^is_steve, limit: 1)
  end
end
