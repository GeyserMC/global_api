defmodule GlobalApi.SkinsRepo do
  alias GlobalApi.Repo
  alias GlobalApi.PlayerSkin
  alias GlobalApi.UniqueSkin
  import Ecto.Query

  def get_player_skin(id) do
    Repo.one(
      from s in PlayerSkin, join: u in assoc(s, :skin),
                            where: s.bedrock_id == ^id,
                            preload: [
                              skin: u
                            ]
    )
  end

  def create_skin(attrs \\ %{}) do
    %PlayerSkin{}
    |> PlayerSkin.changeset(attrs)
    |> Repo.insert(on_conflict: {:replace_all_except, [:inserted_at]})
  end

  def get_unique_skin(hash, is_steve) when is_binary(hash) do
    Repo.one(from s in UniqueSkin, where: s.hash == ^hash and s.is_steve == ^is_steve, limit: 1)
  end

  def create_unique_skin(attrs) when is_map(attrs) do
    %UniqueSkin{}
    |> UniqueSkin.changeset(attrs)
    |> Repo.insert!(on_conflict: :nothing)
    # on conflict id will be nil
  end

  def create_or_get_unique_skin(attrs) when is_map(attrs) do
    skin_id = create_unique_skin(attrs).id
    # I don't think that this will ever happen, but just in case
    if skin_id == nil do
      get_unique_skin(attrs.hash, attrs.is_steve).id
    else
      skin_id
    end
  end

  def set_skin(xuid, %UniqueSkin{} = unique_skin) do
    set_skin(xuid, unique_skin.id)
  end

  def set_skin(xuid, skin_id) when is_integer(skin_id) do
    %{
      bedrock_id: xuid,
      skin_id: skin_id
    }
    |> create_skin
  end
end
