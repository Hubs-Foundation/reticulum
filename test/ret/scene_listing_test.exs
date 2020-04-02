defmodule Ret.SceneListingTest do
  use Ret.DataCase
  import Ret.TestHelpers

  alias Ret.{Repo, Scene, SceneListing}

  setup [:create_account, :create_owned_file, :create_scene, :create_scene_listing]

  test "should be able to create scene listing", %{scene: scene, scene_listing: listing} do
    listing = Repo.get_by(SceneListing, scene_listing_id: listing.scene_listing_id)
    assert listing.name == scene.name
    assert listing.description == scene.description
    assert listing.tags == %{"tags" => ["foo", "bar", "biz"]}
  end

  test "listings for an scene become unlisted when deleting it", %{scene: scene, scene_listing: listing} do
    Scene.delete_scene_and_delist_listings(scene)

    assert Scene.scene_or_scene_listing_by_sid(scene.scene_sid) == nil

    listing = SceneListing |> Repo.get(listing.scene_listing_id)

    assert listing.state == :delisted
    assert listing.scene_id == nil
  end
end
