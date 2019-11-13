defmodule RetWeb.Api.V1.SceneView do
  use RetWeb, :view
  alias Ret.{OwnedFile, Scene, SceneListing, Project}

  def render("create.json", %{scene: scene}) do
    %{scenes: [render_scene(scene)]}
  end

  def render("show.json", %{scene: scene}) do
    %{scenes: [render_scene(scene)]}
  end

  def render_scene(%Scene{state: :removed}), do: nil
  def render_scene(%SceneListing{state: :delisted}), do: nil

  # scene var passed in can be either a Ret.Scene or Ret.SceneListing
  def render_scene(scene) do
    map = %{
      scene_id: scene |> Scene.to_sid(),
      parent_scene_id: scene.parent_scene |> Scene.to_sid(),
      parent_scene_listing_id: scene.parent_scene_listing |> Scene.to_sid(),
      project_id: scene.project |> Project.to_sid(),
      name: scene.name,
      description: scene.description,
      attributions: scene.attributions,
      model_url: scene.model_owned_file |> OwnedFile.uri_for() |> URI.to_string(),
      screenshot_url: scene.screenshot_owned_file |> OwnedFile.uri_for() |> URI.to_string(),
      url: scene |> Scene.to_url()
    }

    remix_fields =
      if allow_remixing?(scene) && scene.scene_owned_file do
        %{scene_project_url: scene.scene_owned_file |> OwnedFile.uri_for() |> URI.to_string()}
      else
        %{}
      end

    map |> add_scene_or_listing_fields(scene) |> Map.merge(remix_fields)
  end

  defp add_scene_or_listing_fields(map, %SceneListing{} = scene_listing) do
    map
    |> add_scene_or_listing_fields(scene_listing.scene)
    |> Meap.merge(%{
      type: "scene_listing"
    })
  end

  defp add_scene_or_listing_fields(map, %Scene{} = scene) do
    map
    |> Map.merge(%{
      attribution: scene.attribution,
      allow_remixing: scene.allow_remixing,
      allow_promotion: scene.allow_promotion,
      type: "scene"
    })
  end

  defp allow_remixing?(%SceneListing{} = scene_listing), do: scene_listing.scene.allow_remixing
  defp allow_remixing?(%Scene{} = scene), do: scene.allow_remixing
end
