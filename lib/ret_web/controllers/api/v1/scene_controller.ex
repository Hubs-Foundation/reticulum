defmodule RetWeb.Api.V1.SceneController do
  use RetWeb, :controller

  alias Ret.{Repo, Scene, StoredFiles}

  plug(RetWeb.Plugs.RateLimit when action in [:create, :update])

  def show(conn, %{"id" => scene_id}) do
    scene = Repo.get(Scene, scene_id)

    case scene do
      nil -> conn |> send_resp(404, "scene not found")
      _ -> render(conn, "show.json", scene: scene)
    end
  end

  def update(conn, %{"id" => id, "scene" => params}) do
    case Scene
         |> Repo.get_by(scene_sid: id)
         |> Repo.preload([:account, :model_stored_file, :screenshot_stored_file]) do
      %Scene{} = scene -> create_or_update(conn, params, scene)
      _ -> conn |> send_resp(404, "not found")
    end
  end

  def create(conn, %{"scene" => params}) do
    create_or_update(conn, params)
  end

  defp create_or_update(conn, params, scene \\ %Scene{}) do
    account = Guardian.Plug.current_resource(conn)

    stored_file_results =
      StoredFiles.promote(
        %{
          model: {params["model_file_id"], params["model_file_token"]},
          screenshot: {params["screenshot_file_id"], params["screenshot_file_token"]}
        },
        account
      )

    promotion_error =
      stored_file_results |> Map.values() |> Enum.filter(&(elem(&1, 0) == :error)) |> Enum.at(0)

    case promotion_error do
      nil ->
        %{model: {:ok, model_file}, screenshot: {:ok, screenshot_file}} = stored_file_results

        {result, scene} =
          scene
          |> Scene.changeset(account, model_file, screenshot_file, params)
          |> Repo.insert_or_update()

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

  defp first_error_result_from_promotion_results(promotion_results) do
    promotion_results
    |> Map.values()
    |> Enum.find(&(elem(&1, 0) == :error))
  end
end
