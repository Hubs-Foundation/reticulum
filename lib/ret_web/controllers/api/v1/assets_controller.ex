defmodule RetWeb.Api.V1.AssetsController do
  use RetWeb, :controller

  alias Ret.{Asset, Repo, Storage}

  # Limit to 1 TPS
  plug(RetWeb.Plugs.RateLimit when action in [:create])

  def create(conn, %{"asset" => params}) do
    account = Guardian.Plug.current_resource(conn)

    thumbnail_result =
      if params["thumbnail_file_id"] && params["thumbnail_access_token"] do
        Storage.promote(
          params["thumbnail_file_id"],
          params["thumbnail_access_token"],
          nil,
          account
        )
      else
        {:ok, nil}
      end

    with {:ok, asset_owned_file} <-
           Storage.promote(params["file_id"], params["access_token"], nil, account),
         {:ok, thumbnail_owned_file} <- thumbnail_result,
         {:ok, asset} <-
           Asset.create_asset(account, asset_owned_file, thumbnail_owned_file, params) do
      render(conn, "show.json", asset: asset)
    else
      {:error, error} -> render_error_json(conn, error)
    end
  end

  def delete(conn, %{"id" => asset_sid}) do
    account = Guardian.Plug.current_resource(conn)

    case Asset.asset_by_sid_for_account(asset_sid, account) do
      %Asset{} = asset ->
        Repo.delete(asset)
        send_resp(conn, 200, "OK")

      nil ->
        render_error_json(conn, :not_found)
    end
  end
end
