defmodule RetWeb.ProjectsControllerTest do
  use RetWeb.ConnCase
  import Ret.TestHelpers

  alias Ret.{Project, Repo, Account}

  setup [:create_account, :create_project_owned_file, :create_thumbnail_owned_file, :create_project]

  setup do
    on_exit(fn ->
      clear_all_stored_files()
    end)
  end

  test "projects create 401's when not logged in", %{conn: conn} do
    params = %{ project: %{ name: "Test Project" } }
    conn |> post(api_v1_project_path(conn, :create)) |> response(401)
  end

  @tag :authenticated
  test "projects create works when logged in", %{conn: conn} do
    params = %{ project: %{ name: "Test Project" } }
    conn |> post(api_v1_project_path(conn, :create, params)) |> response(200)
  end

  test "projects delete 401's when not logged in", %{conn: conn, project: project} do
    conn |> delete(api_v1_project_path(conn, :delete, project.project_sid)) |> response(401)
  end

  @tag :authenticated
  test "projects delete works when logged in", %{conn: conn, project: project} do
    conn |> delete(api_v1_project_path(conn, :delete, project.project_sid)) |> response(200)

    deleted_project = Project |> Repo.get_by(project_sid: project.project_sid)

    assert deleted_project == nil
  end

  @tag :authenticated
  test "projects delete shows a 404 when the user does not own the project", %{conn: conn, project_owned_file: project_owned_file, thumbnail_owned_file: thumbnail_owned_file} do
    other_account = Account.account_for_email("test2@mozilla.com")

    {:ok, project} = %Project{}
      |> Project.changeset(other_account, project_owned_file, thumbnail_owned_file, %{
        name: "Test Scene"
      })
      |> Repo.insert_or_update()

    conn |> delete(api_v1_project_path(conn, :delete, project.project_sid)) |> response(404)

    deleted_project = Project |> Repo.get_by(project_sid: project.project_sid)

    assert deleted_project != nil
  end
end
