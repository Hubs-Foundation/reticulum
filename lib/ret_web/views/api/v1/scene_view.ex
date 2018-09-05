defmodule RetWeb.Api.V1.SceneView do
  use RetWeb, :view

  defp url_for_scene(scene) do
    "#{RetWeb.Endpoint.url()}/scenes/#{scene.scene_sid}/#{scene.slug}"
  end

  def render("create.json", %{scene: scene}) do
    %{
      status: :ok,
      scene_id: scene.scene_sid,
      url: url_for_scene(scene)
    }
  end

  def render("show.json", %{scene: scene}) do
    %{
      scenes: [
        %{
          scene_id: scene.scene_sid,
          name: scene.name,
          description: scene.description,
          model_url: "",
          screenshot_url: "",
          url: url_for_scene(scene)
        }
      ]
    }
  end
end
