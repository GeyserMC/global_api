defmodule GlobalApiWeb.Skin.SkinsController do
  @moduledoc false
  use GlobalApiWeb, :controller

  def index(conn, _) do
    redirect(conn, to: Routes.live_path(conn, GlobalApiWeb.Skin.RecentBedrock))
  end
end
