defmodule RetWeb.Api.V1.SceneController do
  use RetWeb, :controller

  alias Ret.{Account, Repo, Scene, SceneListing, Storage, Asset, OwnedFile, Hub}

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

  def show(conn, params) do
    IO.puts("show inside scene_controller")
    IO.inspect(params)
    # get the scene dependencies
    %{
      # parent_scene_listing: nil,
      # parent_scene_listing_id: nil,

      account_id: account_id,
      scene_id: scene_id,
      model_owned_file: model_owned_file, # Ret.OwnedFile
      scene_owned_file: scene_owned_file, # Ret.OwnedFile
      screenshot_owned_file: screenshot_owned_file, # Ret.OwnedFile

      model_owned_file_id: _model_owned_file_id,
      scene_owned_file_id: _scene_owned_file_id,
      screenshot_owned_file_id: _screenshot_owned_file_id,
     } = scene = get_scene("zvzRZT3") # zvzRZT3 Need the scene_sid

     %{
       scene_listing_id: scene_listing_id
     } = scene_listing = SceneListing
     |> Repo.get_by(_scene_id: scene_id)
     |> Repo.preload()
     IO.puts(1)
     IO.puts(scene_listing_id)
     IO.puts(2)

    # Get Hub Dependencies
    # if user says use default scene
      # set room scene to default scene id
      assign_hub_new_scene = SceneListing.get_random_default_scene_listing() # need to remove our scene listing first or demote it
      IO.inspect(assign_hub_new_scene)
      # see hub_controller for how it reassigns hubs scenes
      # Hub.changeset_for_new_scene(hub, scene (or scenelisting))
      #  Hub.changeset_for_new_scene(hub, assign_hub_new_scene)
      # ?? is changeset a list of scenes for a hub??
      # update scene image url for featured image for hub
    # else
      # return here with list of room ids
      IO.puts(3)
     maybe_more_than_one_hub = Hub
     |> Repo.get_by(scene_listing_id: scene_listing_id)
     |> Repo.preload()
     IO.puts(4)
     IO.inspect(maybe_more_than_one_hub)
     IO.puts(5)


     ## START DELETING ##

     # ATOMICALLY how do I atomically do this, if any step fails it reactivates the files?
      # Demote for being cleaned up by vacuum()
      # Reset if something goes wrong
      # model_owned_file.inactive()
      # scene_owned_file.inactive()
      # screenshot_owned_file.inactive()

      # delete from database
      # Repo.delete(scene)
      # delete from SceneListing
      # Repo.delete()

    conn |> send_resp(200, "sucessfully deleted")
  end

  def show(conn, %{"id" => scene_sid}) do
    account = Guardian.Plug.current_resource(conn)

    case scene_sid |> get_scene() do
      %t{} = s when t in [Scene, SceneListing] -> conn |> render("show.json", scene: s, account: account)
      _ -> conn |> send_resp(404, "not found")
    end
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
    IO.puts("scene controller get_scene()")
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
      Storage.promote(
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

#   {
#     "id":744131011654189083,
# "_text_id":"744131011654189083",
# "scene_sid":"VrnWHHF",
# "slug":"meetingroom",
# "name":"meetingroom",
# "description":null,
# "account_id":744121974900391938,
# "model_owned_file_id":744131008298745880,
# "screenshot_owned_file_id":744131008424575001,
# "state":"active",
# "inserted_at":"2020-07-10T20:36:10",
# "updated_at":"2020-07-10T20:36:10",
# "attribution":null,
# "allow_remixing":true,
# "allow_promotion":true,
# "scene_owned_file_id":744131011536748570,
# "attributions":{"content": [], "creator": ""},
# "reviewed_at":"2020-07-10T20:36:11"}
#
#
# https://hubs.local:4000/api/postgrest/scenes?limit=10&offset=0&order=id.desc
# [{"id":744131011654189083,
# "_text_id":"744131011654189083",
# "scene_sid":"VrnWHHF",
# "slug":"meetingroom",
# "name":"meetingroom",
# "description":null,
# "account_id":744121974900391938,
# "model_owned_file_id":744131008298745880,
# "screenshot_owned_file_id":744131008424575001,
# "state":"active",
# "inserted_at":"2020-07-10T20:36:10",
# "updated_at":"2020-07-10T20:36:10",
# "attribution":null,
# "allow_remixing":true,
# "allow_promotion":true,
# "scene_owned_file_id":744131011536748570,
# "attributions":{"content": [], "creator": ""},
# "reviewed_at":"2020-07-10T20:36:11"}]
#
#   def show(conn, %{"id" => scene_sid}) do
#     IO.puts("test")

#     case scene_sid |> get_scene() do
#       %t{} = s when t in [Scene, SceneListing] -> conn |> render("show.json", scene: s, account: account)
#       _ -> conn |> send_resp(404, "not found")
#     end
# #     # get dependencies for scene
# #     # belongs to :parent_scene ( okay to delete )
# #     # belongs to :account -> check no refs
# #     # belongs_to :model_owned_file
# #     # belongs to :scene_owned_file project exists with scene? (has one)
# #     # scene listing
# # #     <% collection = %{"List" => ["Item", "Item", "Item"]} %>
# # # <%= for {key, list} <- collection do %>
# # #   <%= key %> # List
# # #   <%= for item <- list do %>
# # #     <%= item %> # Item
# # #   <% end %>
# # # <% end %>
#   end

  def delete(conn,  %{"id" => _scene_sid} = params) do
    _account = Guardian.Plug.current_resource(conn)
    # Repo.delete(asset)

    IO.inspect(params)
    # if dependencies
    #   returns the delete projects
    #
  end
end
