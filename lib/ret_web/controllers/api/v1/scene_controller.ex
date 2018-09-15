defmodule RetWeb.Api.V1.SceneController do
  use RetWeb, :controller

  alias Ret.{Repo, Scene, Storage}

  plug(RetWeb.Plugs.RateLimit when action in [:create, :update])

  def show(conn, %{"id" => scene_sid}) do
    case scene_sid |> get_scene() do
      %Scene{} = scene -> conn |> render("show.json", scene: scene)
      _ -> conn |> send_resp(404, "not found")
    end
  end

  def update(conn, %{"id" => scene_sid, "scene" => params}) do
    case scene_sid |> get_scene() do
      %Scene{} = scene -> create_or_update(conn, params, scene)
      _ -> conn |> send_resp(404, "not found")
    end
  end

  def create(conn, %{"scene" => params}) do
    create_or_update(conn, params)
  end

  defp get_scene(scene_sid) do
    Scene
    |> Repo.get_by(scene_sid: scene_sid)
    |> Repo.preload([:account, :model_owned_file, :screenshot_owned_file])
  end

  defp create_or_update(conn, params, scene \\ %Scene{}) do
    account = Guardian.Plug.current_resource(conn)

    owned_file_results =
      Storage.promote(
        %{
          model: {params["model_file_id"], params["model_file_token"]},
          screenshot: {params["screenshot_file_id"], params["screenshot_file_token"]}
        },
        account
      )

    promotion_error = owned_file_results |> Map.values() |> Enum.filter(&(elem(&1, 0) == :error)) |> Enum.at(0)

    case promotion_error do
      nil ->
        %{model: {:ok, model_file}, screenshot: {:ok, screenshot_file}} = owned_file_results

        {result, scene} =
          scene
          |> Scene.changeset(account, model_file, screenshot_file, params)
          |> Repo.insert_or_update()

        scene =
          scene
          |> Repo.preload([:model_owned_file, :screenshot_owned_file])

        case result do
          :ok ->
            conn |> render("create.json", scene: scene)

          :error ->
            conn |> send_resp(422, "invalid scene")
        end

      {:error, :not_found} ->
        conn |> send_resp(404, "no such file(s)")

      {:error, :not_allowed} ->
        conn |> send_resp(401, "")
    end
  end
end
