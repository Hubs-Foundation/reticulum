defmodule RetWeb.Api.V1.ProjectController do
  use RetWeb, :controller

  alias Ret.{Project, Repo, Storage, Scene, SceneListing}

  # Limit to 1 TPS
  plug RetWeb.Plugs.RateLimit when action in [:create]

  defp preload(project) do
    project
    |> Repo.preload([
      :project_owned_file,
      :thumbnail_owned_file,
      scene: Scene.scene_preloads(),
      parent_scene: Scene.scene_preloads(),
      parent_scene_listing: [
        :model_owned_file,
        :screenshot_owned_file,
        :scene_owned_file,
        :project,
        :account,
        scene: Scene.scene_preloads()
      ]
    ])
  end

  def index(conn, %{} = _params) do
    account = Guardian.Plug.current_resource(conn)
    projects = Project.projects_for_account(account)
    render(conn, "index.json", projects: projects)
  end

  def show(conn, %{"id" => project_sid}) do
    account = Guardian.Plug.current_resource(conn)

    case Project.project_by_sid_for_account(project_sid, account) do
      %Project{} = project -> render(conn, "show.json", project: project)
      nil -> render_error_json(conn, :not_found)
    end
  end

  def create(conn, %{"project" => %{"parent_scene_id" => parent_scene_sid} = params}) do
    account = Guardian.Plug.current_resource(conn)

    case parent_scene_sid |> Scene.scene_or_scene_listing_by_sid() do
      %t{} = s when t in [Scene, SceneListing] ->
        conn |> create_or_update_project(account, params, %Project{}, s)

      _ ->
        conn |> send_resp(404, "not found")
    end
  end

  def create(conn, %{"project" => params}) do
    account = Guardian.Plug.current_resource(conn)
    create_or_update_project(conn, account, params, %Project{})
  end

  def update(conn, %{"id" => project_sid, "project" => params}) do
    account = Guardian.Plug.current_resource(conn)

    with %Project{} = project <- Project.project_by_sid_for_account(project_sid, account) do
      create_or_update_project(conn, account, params, project)
    else
      nil -> render_error_json(conn, :not_found)
    end
  end

  defp create_or_update_project(conn, account, params, project, parent_scene \\ nil) do
    promotion_params = %{
      project: {params["project_file_id"], params["project_file_token"]},
      thumbnail: {params["thumbnail_file_id"], params["thumbnail_file_token"]}
    }

    with %{project: {:ok, project_file}, thumbnail: {:ok, thumbnail_file}} <-
           Storage.promote(promotion_params, account),
         {:ok, project} <-
           project
           |> Project.changeset(account, project_file, thumbnail_file, parent_scene, params)
           |> Repo.insert_or_update() do
      project = project |> preload()

      render(conn, "show.json", project: project)
    else
      {:error, error} -> render_error_json(conn, error)
      nil -> render_error_json(conn, :not_found)
    end
  end

  def delete(conn, %{"id" => project_sid}) do
    account = Guardian.Plug.current_resource(conn)

    with %Project{} = project <- Project.project_by_sid_for_account(project_sid, account),
         {:ok, _} <- Repo.delete(project) do
      send_resp(conn, 200, "OK")
    else
      {:error, error} -> render_error_json(conn, error)
      nil -> render_error_json(conn, :not_found)
    end
  end

  def publish(conn, %{"project_id" => project_sid, "scene" => scene_params}) do
    account = Guardian.Plug.current_resource(conn)

    conn
    |> publish_project(
      scene_params,
      project_sid |> Project.project_by_sid_for_account(account),
      account
    )
  end

  def publish(conn, %{"project_id" => _project_sid}) do
    conn |> render_error_json(400, "You must provide a valid scene to publish")
  end

  defp publish_project(conn, _scene_params, _project = nil, _account) do
    conn |> render_error_json(:not_found)
  end

  defp publish_project(conn, scene_params, project = %Project{scene: nil}, account) do
    conn |> publish_project(scene_params, project, %Scene{}, account)
  end

  defp publish_project(conn, scene_params, project = %Project{scene: scene}, account) do
    conn |> publish_project(scene_params, project, scene, account)
  end

  defp publish_project(conn, scene_params, project = %Project{}, scene = %Scene{}, account) do
    {:ok, conn} =
      Repo.transaction(fn ->
        with {:ok, model_owned_file} <-
               Storage.promote(
                 scene_params["model_file_id"],
                 scene_params["model_file_token"],
                 nil,
                 account
               ),
             {:ok, screenshot_owned_file} <-
               Storage.promote(
                 scene_params["screenshot_file_id"],
                 scene_params["screenshot_file_token"],
                 nil,
                 account
               ),
             {:ok, scene_owned_file} <-
               Storage.promote(
                 scene_params["scene_file_id"],
                 scene_params["scene_file_token"],
                 nil,
                 account
               ),
             scene_changes <-
               scene
               |> Scene.changeset(
                 account,
                 model_owned_file,
                 screenshot_owned_file,
                 scene_owned_file,
                 project.parent_scene_listing || project.parent_scene,
                 scene_params
               ),
             {:ok, updated_project} <- project |> Project.add_scene_to_project(scene_changes),
             scene <- updated_project.scene do
          if scene.allow_promotion,
            do: Task.async(fn -> scene |> Ret.Support.send_notification_of_new_scene() end)

          conn |> render("show.json", project: updated_project |> preload())
        else
          {:error, :not_found} ->
            conn
            |> render_error_json(
              400,
              "You must provide a valid model, screenshot, and scene file"
            )

          {:error, error} ->
            conn |> render_error_json(error)
        end
      end)

    conn
  end
end
