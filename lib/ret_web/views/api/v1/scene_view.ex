defmodule RetWeb.Api.V1.SceneView do
  use RetWeb, :view
  alias Ret.Scene

  defp url_for_scene(scene) do
    "#{RetWeb.Endpoint.url()}/scenes/#{scene.scene_sid}/#{scene.slug}"
  end

  def render("create.json", %{scene: scene}) do
    %{
      status: :ok,
      scene_id: to_string(scene.scene_id),
      url: url_for_scene(scene)
    }
  end

  def render("show.json", %{scene: scene}) do
    %{
      scenes: [
        %{
          scene_id: to_string(scene.scene_id),
          name: scene.name,
          attribution_name: scene.attribution_name,
          attribution_link: scene.attribution_link,
          author_account_id: scene.author_account_id,
          # TODO BP: Maybe these should be upload fetch urls instead
          model_upload_id: scene.model_upload_id,
          screenshot_upload_id: scene.screenshot_upload_id,
          url: url_for_scene(scene)
        }
      ]
    }
  end
end
