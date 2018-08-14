defmodule RetWeb.Api.V1.SceneController do
  use RetWeb, :controller

  alias Ret.Scene
  alias Ret.Repo

  # Limit to 1 TPS
  plug(RetWeb.Plugs.RateLimit)

  # Only allow access with secret header
  plug(RetWeb.Plugs.HeaderAuthorization when action in [:delete])

  def create(conn, %{"scene" => scene_params}) do
    {result, scene} =
      %Scene{}
      |> Scene.changeset(scene_params)
      |> Repo.insert()

    case result do
      :ok -> render(conn, "create.json", scene: scene)
      :error -> conn |> send_resp(422, "invalid scene")
    end
  end
end
