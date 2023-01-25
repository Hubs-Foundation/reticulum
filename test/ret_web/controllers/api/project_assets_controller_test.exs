defmodule RetWeb.ProjectAssetsControllerTest do
  use RetWeb.ConnCase
  import Ret.TestHelpers

  alias Ret.{Account, Asset, Project, ProjectAsset, Repo}

  setup [
    :create_account,
    :create_project_owned_file,
    :create_thumbnail_owned_file,
    :create_project,
    :create_owned_file,
    :create_asset,
    :create_project_asset
  ]

  setup do
    on_exit(fn ->
      clear_all_stored_files()
    end)
  end

  test "project assets index 401's when not logged in", %{conn: conn, project: project} do
    conn
    |> get(api_v1_project_project_assets_path(conn, :index, project.project_sid))
    |> response(401)
  end

  @tag :authenticated
  test "project assets index shows assets", %{conn: conn, project: project} do
    response =
      conn
      |> get(api_v1_project_project_assets_path(conn, :index, project.project_sid))
      |> json_response(200)

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
    assert asset_name == "Test Project Asset"
    assert asset_file_url != nil
    assert asset_thumbnail_url != nil
    assert asset_content_type == "image/png"
    assert asset_content_length == 8258
  end

  test "project assets create 401's when not logged in", %{
    conn: conn,
    project: project,
    thumbnail_owned_file: thumbnail_owned_file
  } do
    params = project_asset_create_or_update_params(thumbnail_owned_file, thumbnail_owned_file)

    conn
    |> post(api_v1_project_project_assets_path(conn, :create, project.project_sid), params)
    |> response(401)
  end

  @tag :authenticated
  test "project asset create adds an asset to a project when passed an asset id", %{
    conn: conn,
    project: project,
    asset: asset
  } do
    params = %{"asset_id" => asset.asset_sid}

    response =
      conn
      |> post(api_v1_project_project_assets_path(conn, :create, project.project_sid), params)
      |> json_response(200)

    %{"assets" => [%{"asset_id" => asset_id}]} = response

    created_asset = Asset |> Repo.get_by(asset_sid: asset_id)

    assert created_asset.name == "Test Asset"
  end

  @tag :authenticated
  test "project asset create works when logged in", %{
    conn: conn,
    project: project,
    thumbnail_owned_file: thumbnail_owned_file
  } do
    # Asset file needs to be an image, video, or model so use the thumbnail_owned_file for both the asset and thumbnail
    params = project_asset_create_or_update_params(thumbnail_owned_file, thumbnail_owned_file)

    response =
      conn
      |> post(api_v1_project_project_assets_path(conn, :create, project.project_sid), params)
      |> json_response(200)

    %{"assets" => [%{"asset_id" => asset_id}]} = response

    created_asset = Asset |> Repo.get_by(asset_sid: asset_id)

    assert created_asset.name == "Name"
  end

  test "project assets delete 401's when not logged in", %{
    conn: conn,
    project_asset: project_asset
  } do
    project = project_asset.project
    asset = project_asset.asset

    conn
    |> delete(
      api_v1_project_project_assets_path(conn, :delete, project.project_sid, asset.asset_sid)
    )
    |> response(401)
  end

  @tag :authenticated
  test "project assets delete works when logged in", %{conn: conn, project_asset: project_asset} do
    project = project_asset.project
    asset = project_asset.asset

    conn
    |> delete(
      api_v1_project_project_assets_path(conn, :delete, project.project_sid, asset.asset_sid)
    )
    |> response(200)

    deleted_asset = Asset |> Repo.get_by(asset_sid: asset.asset_sid)
    deleted_project = Project |> Repo.get_by(project_sid: project.project_sid)

    deleted_project_asset =
      ProjectAsset |> Repo.get_by(project_id: project.project_id, asset_id: asset.asset_id)

    assert deleted_asset != nil
    assert deleted_project != nil
    assert deleted_project_asset == nil
  end

  @tag :authenticated
  test "project assets delete shows a 404 when the user does not own the asset", %{
    conn: conn,
    project_owned_file: project_owned_file,
    thumbnail_owned_file: thumbnail_owned_file
  } do
    other_account = Account.account_for_email("test2@mozilla.com")

    {:ok, project} =
      %Project{}
      |> Project.changeset(other_account, project_owned_file, thumbnail_owned_file, %{
        name: "Test Scene"
      })
      |> Repo.insert_or_update()

    {:ok, asset} =
      %Asset{}
      |> Asset.changeset(other_account, thumbnail_owned_file, thumbnail_owned_file, %{
        name: "Test Project Asset"
      })
      |> Repo.insert_or_update()

    {:ok, project_asset} =
      %ProjectAsset{}
      |> ProjectAsset.changeset(project, asset)
      |> Repo.insert_or_update()

    conn
    |> delete(
      api_v1_project_project_assets_path(
        conn,
        :delete,
        project_asset.project.project_sid,
        project_asset.asset.asset_sid
      )
    )
    |> response(404)
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
