defmodule RetWeb.AssetsControllerTest do
  use RetWeb.ConnCase
  import Ret.TestHelpers

  alias Ret.{Asset, Repo, Account}

  setup [:create_account, :create_thumbnail_owned_file, :create_asset]

  setup do
    on_exit(fn ->
      clear_all_stored_files()
    end)
  end

  test "assets create 401's when not logged in", %{
    conn: conn,
    thumbnail_owned_file: thumbnail_owned_file
  } do
    params = asset_create_params(thumbnail_owned_file, thumbnail_owned_file)
    conn |> post(api_v1_assets_path(conn, :create), params) |> response(401)
  end

  @tag :authenticated
  test "assets create works when logged in", %{
    conn: conn,
    thumbnail_owned_file: thumbnail_owned_file
  } do
    # Asset file needs to be an image, video, or model so use the thumbnail_owned_file for both the asset and thumbnail
    params = asset_create_params(thumbnail_owned_file, thumbnail_owned_file)

    response = conn |> post(api_v1_assets_path(conn, :create), params) |> json_response(200)
    %{"assets" => [%{"asset_id" => asset_id}]} = response

    created_asset = Asset |> Repo.get_by(asset_sid: asset_id)

    assert created_asset.name == "Name"
  end

  test "assets delete 401's when not logged in", %{conn: conn, asset: asset} do
    conn |> delete(api_v1_assets_path(conn, :delete, asset.asset_sid)) |> response(401)
  end

  @tag :authenticated
  test "assets delete works when logged in", %{conn: conn, asset: asset} do
    conn |> delete(api_v1_assets_path(conn, :delete, asset.asset_sid)) |> response(200)

    deleted_asset = Asset |> Repo.get_by(asset_sid: asset.asset_sid)

    assert deleted_asset == nil
  end

  @tag :authenticated
  test "assets delete shows a 404 when the user does not own the asset", %{
    conn: conn,
    thumbnail_owned_file: thumbnail_owned_file
  } do
    other_account = Account.account_for_email("test2@mozilla.com")

    {:ok, asset} =
      %Asset{}
      |> Asset.changeset(other_account, thumbnail_owned_file, thumbnail_owned_file, %{
        name: "Test Asset"
      })
      |> Repo.insert_or_update()

    conn |> delete(api_v1_assets_path(conn, :delete, asset.asset_sid)) |> response(404)

    deleted_asset = Asset |> Repo.get_by(asset_sid: asset.asset_sid)

    assert deleted_asset != nil
  end

  defp asset_create_params(owned_file, thumbnail_owned_file, name \\ "Name") do
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
