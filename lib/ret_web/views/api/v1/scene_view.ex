defmodule RetWeb.Api.V1.SceneView do
  use RetWeb, :view
  alias Ret.{OwnedFile, Scene, SceneListing}

  def render("create.json", %{scene: scene}) do
    %{scenes: [render_scene(scene)]}
  end

  def render("show.json", %{scene: scene}) do
    %{scenes: [render_scene(scene)]}
  end

  def render_scene(scene) do
    %{
      scene_id: scene |> Scene.to_sid(),
      name: scene.name,
      description: scene.description,
      attributions: scene.attributions,
      model_url: scene.model_owned_file |> OwnedFile.uri_for() |> URI.to_string(),
      screenshot_url: scene.screenshot_owned_file |> OwnedFile.uri_for() |> URI.to_string(),
      url: scene |> Scene.to_url()
    }
    |> add_scene_or_listing_fields(scene)
  end

  defp add_scene_or_listing_fields(map, %SceneListing{} = scene_listing) do
    map |> add_scene_or_listing_fields(scene_listing.scene)
  end

  defp add_scene_or_listing_fields(map, %Scene{} = scene) do
    fields = %{
      attribution: scene.attribution,
      allow_remixing: scene.allow_remixing,
      allow_promotion: scene.allow_promotion
    }

    remix_fields =
      if scene.allow_remixing && scene.scene_owned_file do
        %{scene_project_url: scene.scene_owned_file |> OwnedFile.uri_for() |> URI.to_string()}
      else
        %{}
      end

    map |> Map.merge(fields) |> Map.merge(remix_fields)
  end
end
