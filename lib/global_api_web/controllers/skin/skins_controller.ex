defmodule GlobalApiWeb.Skin.SkinsController do
  @moduledoc false
  use GlobalApiWeb, :controller

  def index(conn, _) do
    redirect(conn, to: Routes.skins_path(conn, :recent_bedrock))
  end
end
