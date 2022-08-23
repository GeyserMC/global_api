defmodule GlobalApiWeb.Api.VersionsController do
  use GlobalApiWeb, :controller

  def project_version(conn, %{"project" => project}) do
    version = Cachex.get!(:project_version, project)

    if version do
      json(conn, version)
    else
      conn
      |> put_status(:not_found)
      |> json(%{message: "No version information found for the given project"})
    end
  end
end
