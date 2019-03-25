defmodule RetWeb.Api.V1.ProjectFileController do
  use RetWeb, :controller

  alias Ret.{AccountFile, Project, ProjectFile, Repo, Storage}

  # Limit to 1 TPS
  plug(RetWeb.Plugs.RateLimit when action in [:create])

  def create(conn, %{"id" => project_sid, "project_file" => params}) do
    case Project |> Repo.get_by(project_sid: project_sid) do
      %Project{} = project -> create(conn, params, project)
      _ -> conn |> send_resp(404, "not found")
    end
  end

  defp create(conn, params, project) do
    account = conn |> Guardian.Plug.current_resource()
    
    { owned_file_result, owned_file } = Storage.promote(params["file_id"], params["access_token"], nil, account)
    
    case owned_file_result do
      :ok ->
        {project_file_result, project_file} =
          %ProjectFile{}
          |> ProjectFile.changeset(account, project, owned_file, params)
          |> Repo.insert_or_update()

          project_file = Repo.preload(project_file, [:project_file_owned_file])

        case project_file_result do
          :ok ->
            {account_file_result, account_file} = %AccountFile{}
              |> AccountFile.changeset(account, owned_file, params)
              |> Repo.insert_or_update()
            
            case account_file_result do
              :ok ->
                conn |> render("show.json", project_file: project_file, account_file: account_file)
              :error ->
                conn |> send_resp(422, "invalid account file")
            end
          :error ->
            conn |> send_resp(422, "invalid project file")
        end
      :error ->
        conn |> send_resp(422, "invalid owned file")
    end
  end
end
