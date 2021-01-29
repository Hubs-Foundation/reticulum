defmodule RetWeb.Api.V1.SceneView do
  use RetWeb, :view
  alias Ret.{OwnedFile, Scene, SceneListing, Project}

  def render("create.json", %{scene: scene, account: account}) do
    %{scenes: [render_scene(scene, account)]}
  end

  def render("show.json", %{scene: scene, account: account}) do
    %{scenes: [render_scene(scene, account)]}
  end

  def render("index.json", %{scenes: scenes, account: account}) do
    %{
      scenes: Enum.map(scenes, fn s -> render_scene(s, account) end)
    }
  end

  def render_scene(nil, _account), do: nil
  def render_scene(%Scene{state: :removed}, _account), do: nil
  def render_scene(%SceneListing{state: :delisted}, _account), do: nil

  # scene var passed in can be either a Ret.Scene or Ret.SceneListing
  def render_scene(scene, account) do
    map = %{
      scene_id: scene |> Scene.to_sid(),
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

    map |> add_scene_or_listing_fields(scene, account) |> Map.merge(remix_fields)
  end

  defp add_scene_or_listing_fields(map, %SceneListing{} = scene_listing, account) do
    map
    |> add_scene_or_listing_fields(scene_listing.scene, account)
    |> Map.merge(%{
      type: "scene_listing"
    })
  end

  defp add_scene_or_listing_fields(map, %Scene{} = scene, account) do
    map
    |> Map.merge(%{
      account_id: account && scene.account_id == account.account_id && scene.account_id |> Integer.to_string(),
      parent_scene_id: (scene.parent_scene_listing || scene.parent_scene) |> Scene.to_sid(),
      attribution: scene.attribution,
      allow_remixing: scene.allow_remixing,
      allow_promotion: scene.allow_promotion,
      type: "scene"
    })
  end

  defp allow_remixing?(%SceneListing{} = scene_listing), do: scene_listing.scene.allow_remixing
  defp allow_remixing?(%Scene{} = scene), do: scene.allow_remixing
end
