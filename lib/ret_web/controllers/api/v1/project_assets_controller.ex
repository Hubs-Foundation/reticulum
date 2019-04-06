defmodule RetWeb.Api.V1.ProjectAssetsController do
  use RetWeb, :controller

  alias Ret.{Asset, Project, ProjectAsset, Repo, Storage}

  # Limit to 1 TPS
  plug(RetWeb.Plugs.RateLimit when action in [:create])

  def index(conn, %{"project_id" => project_sid}) do
    account = Guardian.Plug.current_resource(conn)

    case Project.project_by_sid_for_account(account, project_sid) do
      %Project{} = project -> render(conn, "index.json", assets: project.assets)
      nil -> conn |> send_resp(404, "Project not found")
    end
  end

  def create(conn, %{"project_id" => project_sid, "asset_id" => asset_sid}) do
    account = conn |> Guardian.Plug.current_resource()

    case Project.project_by_sid_for_account(account, project_sid) do
      %Project{} = project ->
        case Asset.asset_by_sid_for_account(account, asset_sid) do
          %Asset{} = asset ->
            case Project.add_asset_to_project(project, asset) do
              {:ok, _} ->
                asset = Repo.preload(asset, [:asset_owned_file, :thumbnail_owned_file])
                conn |> render("show.json", asset: asset)
              {:error, _} -> conn |> send_resp(500, "error adding asset to project")
            end
          _ -> conn |> send_resp(404, "Asset not found")
        end
      nil -> conn |> send_resp(404, "Project not found")
    end
  end

  def create(conn, %{"project_id" => project_sid, "asset" => params}) do
    account = conn |> Guardian.Plug.current_resource()

    case Project.project_by_sid_for_account(account, project_sid) do
      %Project{} = project -> create(conn, params, account, project)
      nil -> conn |> send_resp(404, "Project not found")
    end
  end

  defp create(conn, params, account, project) do
    case Storage.promote(params["file_id"], params["access_token"], nil, account) do
      {:ok, asset_owned_file} ->
        case Storage.promote(params["thumbnail_file_id"], params["thumbnail_access_token"], nil, account) do
          {:ok, thumbnail_owned_file} ->
            case Asset.create_asset_and_project_asset(account, project, asset_owned_file, thumbnail_owned_file, params) do
              {:ok, result} ->
                asset = Repo.preload(result.asset, [:asset_owned_file, :thumbnail_owned_file])
                conn |> render("show.json", asset: asset)
              {:error, :asset, _changeset, %{}} ->
                conn |> send_resp(422, "Invalid asset")
              {:error, :project_asset, _changeset, %{}} ->
                conn |> send_resp(500, "Error creating project asset")
            end
          {:error, _reason} ->
              conn |> send_resp(422, "invalid owned file")
        end
      {:error, _reason} ->
        conn |> send_resp(422, "invalid owned file")
    end
  end

  def delete(conn, %{"project_id" => project_sid, "id" => asset_sid }) do
    account = Guardian.Plug.current_resource(conn)

    case Project.project_by_sid_for_account(account, project_sid) do
      %Project{} = project -> 
        case Asset.asset_by_sid_for_account(account, asset_sid) do
          %Asset{} = asset -> 
            case Repo.get_by(ProjectAsset, [project_id: project.project_id, asset_id: asset.asset_id]) do
              %ProjectAsset{} = project_asset ->
                case Repo.delete(project_asset) do
                  {:ok, _} -> conn |> send_resp(200, "OK")
                  {:error, _} -> conn |> send_resp(500, "error removing project asset")
                end
            end
          _ -> conn |> send_resp(404, "not found")
        end
      _ -> conn |> send_resp(404, "not found")
    end
  end
end
