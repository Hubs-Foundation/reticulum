defmodule RetWeb.Api.V1.SceneController do
  use RetWeb, :controller

  alias Ret.Scene
  alias Ret.Repo

  # Limit to 1 TPS
  plug(RetWeb.Plugs.RateLimit)

  def show(conn, %{"id" => scene_sid}) do
    scene = Repo.get_by(Scene, scene_sid: scene_sid)
    case scene do
      nil -> conn |> send_resp(404, "scene not found")
      _ -> render(conn, "show.json", scene: scene)
    end
  end

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
