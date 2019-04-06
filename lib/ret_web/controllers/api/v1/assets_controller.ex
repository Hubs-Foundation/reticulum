defmodule RetWeb.Api.V1.AssetsController do
  use RetWeb, :controller

  alias Ret.{Asset, Repo, Storage}

  # Limit to 1 TPS
  plug(RetWeb.Plugs.RateLimit when action in [:create])

  def create(conn, %{"asset" => params}) do
    account = conn |> Guardian.Plug.current_resource()

    case Storage.promote(params["file_id"], params["access_token"], nil, account) do
      {:ok, asset_owned_file} ->
        case Storage.promote(params["thumbnail_file_id"], params["thumbnail_access_token"], nil, account) do
          {:ok, thumbnail_owned_file} ->
            case Asset.create_asset(account, asset_owned_file, thumbnail_owned_file, params) do
              {:ok, asset} ->
                conn |> render("show.json", asset: asset)
              {:error, _reason} ->
                conn |> send_resp(500, "error creating asset")
            end
          {:error, _reason} ->
              conn |> send_resp(422, "invalid owned file")
        end
      {:error, _reason} ->
        conn |> send_resp(422, "invalid owned file")
    end
  end

  def delete(conn, %{"id" => asset_sid }) do
    account = Guardian.Plug.current_resource(conn)

    case Asset.asset_by_sid_for_account(account, asset_sid) do
      %Asset{} = asset ->
        case Repo.delete(asset) do
          {:ok, _} -> conn |> send_resp(200, "OK")
          {:error, _} -> conn |> send_resp(500, "error deleting asset")
        end
      _ -> conn |> send_resp(404, "not found")
    end
  end
end
