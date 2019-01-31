defmodule RetWeb.Api.V1.SceneView do
  use RetWeb, :view
  alias Ret.OwnedFile

  defp url_for_scene(scene) do
    "#{RetWeb.Endpoint.url()}/scenes/#{scene.scene_sid}/#{scene.slug}"
  end

  def render("create.json", %{scene: scene}) do
    %{scenes: [render_scene(scene)]}
  end

  def render("show.json", %{scene: scene}) do
    %{scenes: [render_scene(scene)]}
  end

  def render_scene(scene) do
    %{
      scene_id: scene.scene_sid,
      name: scene.name,
      description: scene.description,
      attribution: scene.attribution,
      attributions: scene.attributions,
      model_url: scene.model_owned_file |> OwnedFile.uri_for() |> URI.to_string(),
      screenshot_url: scene.screenshot_owned_file |> OwnedFile.uri_for() |> URI.to_string(),
      allow_remixing: scene.allow_remixing,
      allow_promotion: scene.allow_promotion,
      url: url_for_scene(scene)
    }
  end
end
