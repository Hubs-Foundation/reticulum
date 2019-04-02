defmodule RetWeb.ProjectAssetsControllerTest do
  use RetWeb.ConnCase
  import Ret.TestHelpers

  alias Ret.{Asset, Repo}

  setup [:create_account, :create_project_owned_file, :create_thumbnail_owned_file, :create_project, :create_owned_file, :create_project_asset]

  setup do
    on_exit(fn ->
      clear_all_stored_files()
    end)
  end

  test "project assets index 401's when not logged in", %{conn: conn, project: project} do
    conn |> get(api_v1_project_assets_path(conn, :index, project.project_sid)) |> response(401)
  end

  @tag :authenticated
  test "project assets index shows assets", %{conn: conn, project: project} do
    response = conn |> get(api_v1_project_assets_path(conn, :index, project.project_sid)) |> json_response(200)


    %{
      "assets" => [
        %{
          "asset_id" => asset_id,
          "name" => asset_name,
          "file_url" => asset_file_url,
          "thumbnail_url" => asset_thumbnail_url,
          "content_type" => asset_content_type,
          "content_length" => asset_content_length
        }
      ]
    } = response

    assert asset_id != nil
    assert asset_name == "Test Asset"
    assert asset_file_url != nil
    assert asset_thumbnail_url != nil
    assert asset_content_type == "image/png"
    assert asset_content_length == 8258
  end

  test "project assets create 401's when not logged in", %{conn: conn, project: project, thumbnail_owned_file: thumbnail_owned_file} do
    params = project_asset_create_or_update_params(thumbnail_owned_file, thumbnail_owned_file)
    conn |> post(api_v1_project_assets_path(conn, :create, project.project_sid), params) |> response(401)
  end

  @tag :authenticated
  test "project asset create works when logged in", %{conn: conn, project: project, thumbnail_owned_file: thumbnail_owned_file} do
    # Asset file needs to be an image, video, or model so use the thumbnail_owned_file for both the asset and thumbnail
    params = project_asset_create_or_update_params(thumbnail_owned_file, thumbnail_owned_file)

    response = conn |> post(api_v1_project_assets_path(conn, :create, project.project_sid), params) |> json_response(200)
    %{"assets" => [%{"asset_id" => asset_id}]} = response

    created_asset = Asset |> Repo.get_by(asset_sid: asset_id)

    assert created_asset.name == "Name"
  end

  defp project_asset_create_or_update_params(owned_file, thumbnail_owned_file, name \\ "Name") do
    %{
      "asset" => %{
        "name" => name,
        "file_id" => owned_file.owned_file_uuid,
        "access_token" => owned_file.key,
        "thumbnail_file_id" => thumbnail_owned_file.owned_file_uuid,
        "thumbnail_access_token" => thumbnail_owned_file.key
      }
    }
  end
end
