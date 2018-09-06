defmodule RetWeb.Api.V1.SceneController do
  use RetWeb, :controller

  alias Ret.Scene
  alias Ret.Repo

  plug(RetWeb.Plugs.RateLimit when action in [:create])

  def show(conn, %{"id" => scene_id}) do
    scene = Repo.get(Scene, scene_id)

    case scene do
      nil -> conn |> send_resp(404, "scene not found")
      _ -> render(conn, "show.json", scene: scene)
    end
  end

  def create(conn, %{"scene" => scene_params}) do
    {result, scene} =
      %Scene{}
      |> Scene.changeset(scene_params)
      |> Repo.insert(returning: true)

    case result do
      :ok -> render(conn, "create.json", scene: scene)
      :error -> conn |> send_resp(422, "invalid scene")
    end
  end
end
