defmodule Ret.SceneListingTest do
  use Ret.DataCase
  import Ret.TestHelpers

  alias Ret.{Repo, MediaSearch, MediaSearchQuery}

  setup [:create_account, :create_owned_file, :create_scene, :create_scene_listing]

  test "should be able to create scene listing", %{scene: scene, scene_listing: listing} do
    listing = Repo.get_by(Ret.SceneListing, scene_listing_id: listing.scene_listing_id)
    assert listing.name == scene.name
    assert listing.description == scene.description
    assert listing.tags == ["foo", "bar", "biz"]
  end

  test "should be able to look up pending scenes", %{scene: scene} do
    query = %MediaSearchQuery{source: "pending_scenes"}
    res = MediaSearch.search(query)

    first_scene = res.entries |> Enum.at(0)
    assert first_scene.scene_id == scene.scene_id
  end
end
