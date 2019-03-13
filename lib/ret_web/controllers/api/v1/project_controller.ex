defmodule RetWeb.Api.V1.ProjectController do
  import Ecto.Query

  use RetWeb, :controller

  alias Ret.{Account, Project, Repo, Storage}

  # Limit to 1 TPS
  plug(RetWeb.Plugs.RateLimit when action in [:create])

  def index(conn, %{} = params) do
    account = Guardian.Plug.current_resource(conn)
    projects = get_projects(account)
    render(conn, "index.json", projects: projects)
  end

  def show(conn, %{"id" => project_sid}) do
    case project_sid |> get_project() do
      %Project{} = project -> render(conn, "show.json", project: project)
      _ -> conn |> send_resp(404, "not found")
    end
  end

  def create(conn, %{"project" => params}) do
    account = conn |> Guardian.Plug.current_resource()

    {result, project} =
      %Project{}
      |> Project.changeset(account, params)
      |> Repo.insert_or_update()

    project = Repo.preload(project, [:project_owned_file, :thumbnail_owned_file])

    case result do
      :ok ->
        conn |> render("show.json", project: project)

      :error ->
        conn |> send_resp(422, "invalid project")
    end
  end

  def update(conn, %{"id" => project_sid, "project" => params}) do
    account = conn |> Guardian.Plug.current_resource()

    case project_sid |> get_project() do
      %Project{} = project -> update(conn, params, project, account)
      _ -> conn |> send_resp(404, "not found")
    end
  end

  defp get_projects(account) do
    Repo.all from p in Project,
      where: p.created_by_account_id == ^account.account_id,
      preload: [:project_owned_file, :thumbnail_owned_file]
  end

  defp get_project(project_sid) do
    Project
    |> Repo.get_by(project_sid: project_sid)
    |> Repo.preload([:created_by_account, :project_owned_file, :thumbnail_owned_file])
  end

  defp update(
         conn,
         _params,
         %Project{created_by_account_id: project_account_id},
         %Account{account_id: account_id}
       )
       when not is_nil(project_account_id) and project_account_id != account_id do
    conn |> send_resp(401, "")
  end

  defp update(conn, params, project, account) do
    owned_file_results =
      Storage.promote(
        %{
          project: {params["project_file_id"], params["project_file_token"]},
          thumbnail: {params["thumbnail_file_id"], params["thumbnail_file_token"]},
        },
        account
      )

    promotion_error = owned_file_results |> Map.values() |> Enum.filter(&(elem(&1, 0) == :error)) |> Enum.at(0)

    case promotion_error do
      nil ->
        %{project: {:ok, project_file}, thumbnail: {:ok, thumbnail_file}} = owned_file_results

        {result, project} =
          project
          |> Project.changeset(account, project_file, thumbnail_file, params)
          |> Repo.update()

        project = Repo.preload(project, [:project_owned_file, :thumbnail_owned_file])

        case result do
          :ok ->
            conn |> render("show.json", project: project)

          :error ->
            conn |> send_resp(422, "invalid project")
        end

      {:error, :not_found} ->
        conn |> send_resp(404, "no such file(s)")

      {:error, :not_allowed} ->
        conn |> send_resp(401, "")
    end
  end
end
