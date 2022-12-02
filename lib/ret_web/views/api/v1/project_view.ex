defmodule RetWeb.Api.V1.ProjectView do
  use RetWeb, :view
  alias Ret.{OwnedFile}

  defp render_project(project) do
    %{
      project_id: project.project_sid,
      name: project.name,
      project_url: OwnedFile.url_or_nil_for(project.project_owned_file),
      thumbnail_url: OwnedFile.url_or_nil_for(project.thumbnail_owned_file),
      scene: RetWeb.Api.V1.SceneView.render_scene(project.scene, nil),
      parent_scene:
        RetWeb.Api.V1.SceneView.render_scene(
          project.parent_scene_listing || project.parent_scene,
          nil
        )
    }
  end

  def render("index.json", %{projects: projects}) do
    %{
      projects: Enum.map(projects, fn p -> render_project(p) end)
    }
  end

  def render("show.json", %{project: project}) do
    Map.merge(
      %{status: :ok},
      render_project(project)
    )
  end
end
