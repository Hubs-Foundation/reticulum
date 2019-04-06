defmodule RetWeb.Api.V1.ProjectController do
  use RetWeb, :controller

  alias Ret.{Project, Repo, Storage}

  # Limit to 1 TPS
  plug(RetWeb.Plugs.RateLimit when action in [:create])

  def index(conn, %{} = _params) do
    account = Guardian.Plug.current_resource(conn)
    projects = Project.projects_for_account(account)
    render(conn, "index.json", projects: projects)
  end

  def show(conn, %{"id" => project_sid}) do
    account = Guardian.Plug.current_resource(conn)
    case Project.project_by_sid_for_account(account, project_sid) do
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

    case Project.project_by_sid_for_account(account, project_sid) do
      %Project{} = project -> update(conn, params, project, account)
      _ -> conn |> send_resp(404, "not found")
    end
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

  def delete(conn, %{"id" => project_sid }) do
    account = Guardian.Plug.current_resource(conn)

    case Project.project_by_sid_for_account(account, project_sid) do
      %Project{} = project -> 
        case Repo.delete(project) do
          {:ok, _} -> conn |> send_resp(200, "OK")
          {:error, _} -> conn |> send_resp(500, "error deleting project")
        end
      _ -> conn |> send_resp(404, "not found")
    end
  end
end
