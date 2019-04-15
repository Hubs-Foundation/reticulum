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

  test "projects index 401's when not logged in", %{conn: conn} do
    conn |> get(api_v1_project_path(conn, :index)) |> response(401)
  end

  @tag :authenticated
  test "projects index works when logged in", %{conn: conn, project: project} do
    response = conn |> get(api_v1_project_path(conn, :index)) |> json_response(200)

    %{
      "projects" => [
        %{
          "thumbnail_url" => thumbnail_url,
          "project_url" => project_url,
          "project_id" => project_id,
          "name" => name
        }
      ]
    } = response

    assert name == "Test Scene"
    assert thumbnail_url != nil
    assert project_url != nil
    assert project_id != nil
  end

  test "projects show 401's when not logged in", %{conn: conn, project: project} do
    conn |> get(api_v1_project_path(conn, :show, project.project_sid)) |> response(401)
  end

  @tag :authenticated
  test "projects show works when logged in", %{conn: conn, project: project} do
    response = conn |> get(api_v1_project_path(conn, :show, project.project_sid)) |> json_response(200)

    %{
      "thumbnail_url" => thumbnail_url,
      "project_url" => project_url,
      "project_id" => project_id,
      "name" => name
    } = response

    assert name == "Test Scene"
    assert thumbnail_url != nil
    assert project_url != nil
    assert project_id != nil
  end

  test "projects create 401's when not logged in", %{conn: conn} do
    params = %{ project: %{ name: "Test Project" } }
    conn |> post(api_v1_project_path(conn, :create)) |> response(401)
  end

  @tag :authenticated
  test "projects create works when logged in", %{conn: conn} do
    params = %{ project: %{ name: "Test Project" } }
    response = conn |> post(api_v1_project_path(conn, :create, params)) |> json_response(200)

    %{
      "thumbnail_url" => thumbnail_url,
      "project_url" => project_url,
      "project_id" => project_id,
      "name" => name
    } = response

    assert name == "Test Project"
    assert thumbnail_url == nil
    assert project_url == nil
    assert project_id != nil
  end

  test "projects update 401's when not logged in", %{conn: conn, project: project, project_owned_file: project_owned_file, thumbnail_owned_file: thumbnail_owned_file} do
    params = %{
      project: %{
        name: "Test Project 2",
        thumbnail_file_id: thumbnail_owned_file.owned_file_uuid,
        thumbnail_file_token: thumbnail_owned_file.key,
        project_file_id: project_owned_file.owned_file_uuid,
        project_file_token: project_owned_file.key
      }
    }

    conn |> patch(api_v1_project_path(conn, :update, project.project_sid, params)) |> response(401)
  end

  @tag :authenticated
  test "projects update works when logged in", %{conn: conn, project: project, project_owned_file: project_owned_file, thumbnail_owned_file: thumbnail_owned_file} do
    params = %{
      project: %{
        name: "Test Project 2",
        thumbnail_file_id: thumbnail_owned_file.owned_file_uuid,
        thumbnail_file_token: thumbnail_owned_file.key,
        project_file_id: project_owned_file.owned_file_uuid,
        project_file_token: project_owned_file.key
      }
    }
    
    response = conn |> patch(api_v1_project_path(conn, :update, project.project_sid, params)) |> json_response(200)

    %{
      "thumbnail_url" => thumbnail_url,
      "project_url" => project_url,
      "project_id" => project_id,
      "name" => name
    } = response

    assert name == "Test Project 2"
    assert thumbnail_url != nil
    assert project_url != nil
    assert project_id != nil
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
