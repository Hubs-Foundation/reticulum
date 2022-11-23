defmodule RetWeb.ProjectsControllerTest do
  use RetWeb.ConnCase
  import Ret.TestHelpers

  alias Ret.{Project, Repo, Account}

  setup [
    :create_account,
    :create_project_owned_file,
    :create_thumbnail_owned_file,
    :create_project,
    :create_model_owned_file
  ]

  setup do
    on_exit(fn ->
      clear_all_stored_files()
    end)
  end

  test "projects index 401's when not logged in", %{conn: conn} do
    conn |> get(api_v1_project_path(conn, :index)) |> response(401)
  end

  @tag :authenticated
  test "projects index works when logged in", %{conn: conn, project: _project} do
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

    assert name == "Test Project"
    assert thumbnail_url != nil
    assert project_url != nil
    assert project_id != nil
  end

  test "projects show 401's when not logged in", %{conn: conn, project: project} do
    conn |> get(api_v1_project_path(conn, :show, project.project_sid)) |> response(401)
  end

  @tag :authenticated
  test "projects show works when logged in", %{conn: conn, project: project} do
    response =
      conn |> get(api_v1_project_path(conn, :show, project.project_sid)) |> json_response(200)

    %{
      "thumbnail_url" => thumbnail_url,
      "project_url" => project_url,
      "project_id" => project_id,
      "name" => name
    } = response

    assert name == "Test Project"
    assert thumbnail_url != nil
    assert project_url != nil
    assert project_id != nil
  end

  test "projects create 401's when not logged in", %{conn: conn} do
    conn |> post(api_v1_project_path(conn, :create)) |> response(401)
  end

  @tag :authenticated
  test "projects create works when logged in", %{
    conn: conn,
    project_owned_file: project_owned_file,
    thumbnail_owned_file: thumbnail_owned_file
  } do
    params = %{
      project: %{
        name: "Test Project",
        thumbnail_file_id: thumbnail_owned_file.owned_file_uuid,
        thumbnail_file_token: thumbnail_owned_file.key,
        project_file_id: project_owned_file.owned_file_uuid,
        project_file_token: project_owned_file.key
      }
    }

    response = conn |> post(api_v1_project_path(conn, :create, params)) |> json_response(200)

    %{
      "thumbnail_url" => thumbnail_url,
      "project_url" => project_url,
      "project_id" => project_id,
      "name" => name
    } = response

    assert name == "Test Project"
    assert thumbnail_url != nil
    assert project_url != nil
    assert project_id != nil
  end

  test "projects update 401's when not logged in", %{
    conn: conn,
    project: project,
    project_owned_file: project_owned_file,
    thumbnail_owned_file: thumbnail_owned_file
  } do
    params = %{
      project: %{
        name: "Test Project 2",
        thumbnail_file_id: thumbnail_owned_file.owned_file_uuid,
        thumbnail_file_token: thumbnail_owned_file.key,
        project_file_id: project_owned_file.owned_file_uuid,
        project_file_token: project_owned_file.key
      }
    }

    conn
    |> patch(api_v1_project_path(conn, :update, project.project_sid, params))
    |> response(401)
  end

  @tag :authenticated
  test "projects update works when logged in", %{
    conn: conn,
    project: project,
    project_owned_file: project_owned_file,
    thumbnail_owned_file: thumbnail_owned_file
  } do
    params = %{
      project: %{
        name: "Test Project 2",
        thumbnail_file_id: thumbnail_owned_file.owned_file_uuid,
        thumbnail_file_token: thumbnail_owned_file.key,
        project_file_id: project_owned_file.owned_file_uuid,
        project_file_token: project_owned_file.key
      }
    }

    response =
      conn
      |> patch(api_v1_project_path(conn, :update, project.project_sid, params))
      |> json_response(200)

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

  @tag :authenticated
  test "projects with no scene creates a new scene on publish", %{
    conn: conn,
    project: project,
    project_owned_file: scene_owned_file,
    thumbnail_owned_file: screenshot_owned_file,
    model_owned_file: model_owned_file
  } do
    params = %{
      scene: %{
        name: "Test Publish",
        allow_promotion: true,
        model_file_id: model_owned_file.owned_file_uuid,
        model_file_token: model_owned_file.key,
        screenshot_file_id: screenshot_owned_file.owned_file_uuid,
        screenshot_file_token: screenshot_owned_file.key,
        scene_file_id: scene_owned_file.owned_file_uuid,
        scene_file_token: scene_owned_file.key
      }
    }

    # Publishing the first time should create a new scene
    project = project |> Repo.preload([:scene])
    assert project.scene == nil

    response_project =
      conn
      |> post(api_v1_project_project_path(conn, :publish, project.project_sid, params))
      |> json_response(200)

    new_scene_sid = response_project["scene"]["scene_id"]

    updated_project =
      Project |> Repo.get_by(project_sid: project.project_sid) |> Repo.preload([:scene])

    assert updated_project.scene.scene_sid == new_scene_sid
    assert response_project["name"] == "Test Project"
    assert response_project["scene"]["name"] == "Test Publish"

    # Republishing should not create a new scene
    params = params |> put_in([:scene, :name], "Test Republish")

    response_project =
      conn
      |> post(api_v1_project_project_path(conn, :publish, project.project_sid, params))
      |> json_response(200)

    assert response_project["scene"]["name"] == "Test Republish"
    assert response_project["scene"]["scene_id"] == new_scene_sid
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
  test "projects delete shows a 404 when the user does not own the project", %{
    conn: conn,
    project_owned_file: project_owned_file,
    thumbnail_owned_file: thumbnail_owned_file
  } do
    other_account = Account.find_or_create_account_for_email("test2@mozilla.com")

    {:ok, project} =
      %Project{}
      |> Project.changeset(other_account, project_owned_file, thumbnail_owned_file, %{
        name: "Test Project"
      })
      |> Repo.insert_or_update()

    conn |> delete(api_v1_project_path(conn, :delete, project.project_sid)) |> response(404)

    deleted_project = Project |> Repo.get_by(project_sid: project.project_sid)

    assert deleted_project != nil
  end
end
