defmodule RetWeb.Api.V1.SceneController do
  use RetWeb, :controller

  alias Ret.{Account, Repo, Scene, SceneListing, Storage, Project}

  plug(RetWeb.Plugs.RateLimit when action in [:create, :update])

  defp preload(%Scene{} = a) do
    a |> Repo.preload(Scene.scene_preloads())
  end

  defp preload(%SceneListing{} = a) do
    a
    |> Repo.preload([
      :model_owned_file,
      :screenshot_owned_file,
      :scene_owned_file,
      :project,
      :account,
      scene: Scene.scene_preloads()
    ])
  end

  def show(conn, %{"id" => scene_sid}) do
    account = Guardian.Plug.current_resource(conn)

    case scene_sid |> get_scene() do
      %t{} = s when t in [Scene, SceneListing] -> conn |> render("show.json", scene: s, account: account)
      _ -> conn |> send_resp(404, "not found")
    end
  end

  def index_projectless(conn, _params) do
    account = Guardian.Plug.current_resource(conn)
    conn |> render("index.json", scenes: Scene.projectless_scenes_for_account(account), account: account)
  end

  def update(conn, %{"id" => scene_sid, "scene" => params}) do
    case scene_sid |> get_scene() do
      %Scene{} = scene -> create_or_update(conn, params, scene)
      _ -> conn |> send_resp(404, "not found")
    end
  end

  def create(conn, %{"parent_scene_id" => scene_sid}) do
    account = Guardian.Plug.current_resource(conn)

    case scene_sid |> get_scene() do
      %t{} = s when t in [Scene, SceneListing] ->
        new_scene = s |> Scene.new_scene_from_parent_scene(account) |> preload()
        conn |> render("show.json", account: account, scene: new_scene)

      _ ->
        conn |> send_resp(404, "not found")
    end
  end

  def create(conn, %{"url" => url}) do
    try do
      account = Guardian.Plug.current_resource(conn)
      new_scene = url |> URI.parse() |> Scene.import_from_url!(account)
      conn |> render("create.json", scene: new_scene |> preload(), account: account)
    rescue
      _ -> render_error_json(conn, 400)
    end
  end

  def create(conn, %{"scene" => params}) do
    create_or_update(conn, params)
  end

  defp get_scene(scene_sid) do
    case scene_sid |> Scene.scene_or_scene_listing_by_sid() do
      nil -> nil
      scene -> scene |> preload()
    end
  end

  defp create_or_update(conn, params, scene \\ %Scene{}) do
    account = conn |> Guardian.Plug.current_resource()
    create_or_update(conn, params, scene, account)
  end

  defp create_or_update(
         conn,
         _params,
         %Scene{account_id: scene_account_id},
         %Account{account_id: account_id}
       )
       when not is_nil(scene_account_id) and scene_account_id != account_id do
    conn |> send_resp(401, "")
  end

  defp create_or_update(conn, params, scene, account) do
    owned_file_results =
      Storage.promote_optional(
        %{
          model: {params["model_file_id"], params["model_file_token"]},
          screenshot: {params["screenshot_file_id"], params["screenshot_file_token"]},
          scene: {params["scene_file_id"], params["scene_file_token"]}
        },
        account
      )

    promotion_error = owned_file_results |> Map.values() |> Enum.filter(&(elem(&1, 0) == :error)) |> Enum.at(0)

    # Legacy
    params = params |> Map.put_new("attributions", %{"extras" => params["attribution"]})

    case promotion_error do
      nil ->
        %{model: {:ok, model_file}, screenshot: {:ok, screenshot_file}, scene: {:ok, scene_file}} = owned_file_results

        {result, scene} =
          scene
          |> Scene.changeset(account, model_file, screenshot_file, scene_file, params)
          |> Repo.insert_or_update()

        scene = scene |> preload()

        if scene.allow_promotion do
          Task.async(fn -> scene |> Ret.Support.send_notification_of_new_scene() end)
        end

        case result do
          :ok ->
            conn |> render("create.json", scene: scene, account: account)

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
