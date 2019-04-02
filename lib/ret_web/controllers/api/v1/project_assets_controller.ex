defmodule RetWeb.Api.V1.ProjectAssetsController do
  use RetWeb, :controller

  alias Ret.{Asset, Project, Repo, Storage}

  # Limit to 1 TPS
  plug(RetWeb.Plugs.RateLimit when action in [:create])

  def index(conn, %{"id" => project_sid}) do
    account = Guardian.Plug.current_resource(conn)

    case Project.project_by_sid_for_account(account, project_sid) do
      %Project{} = project -> render(conn, "index.json", assets: project.assets)
      nil -> conn |> send_resp(404, "Project not found")
    end
  end

  def create(conn, %{"id" => project_sid, "asset" => params}) do
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
end
