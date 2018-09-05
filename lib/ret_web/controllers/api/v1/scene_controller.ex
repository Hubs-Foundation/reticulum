defmodule RetWeb.Api.V1.SceneController do
  use RetWeb, :controller

  alias Ret.{Repo, Scene}

  plug(RetWeb.Plugs.RateLimit when action in [:create])

  def show(conn, %{"id" => scene_id}) do
    scene = Repo.get(Scene, scene_id)

    case scene do
      nil -> conn |> send_resp(404, "scene not found")
      _ -> render(conn, "show.json", scene: scene)
    end
  end

  def create(conn, %{"scene" => scene_params}) do
    account = Guardian.Plug.current_resource(conn)

    %{model_stored_file: model_stored_file, screenshot_stored_file: screenshot_stored_file} =
      Scene.promote_files_from_scene_params(scene_params)

    {result, scene} =
      %Scene{}
      |> Scene.changeset(account, model_stored_file, screenshot_stored_file, scene_params)
      |> Repo.insert(returning: true)

    case result do
      :ok -> render(conn, "create.json", scene: scene)
      :error -> conn |> send_resp(422, "invalid scene")
    end
  end
end
