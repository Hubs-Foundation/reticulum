defmodule RetWeb.Schema.SceneTypes do
  use Absinthe.Schema.Notation
  alias Ret.{Scene, SceneListing}

  @desc "A scene or a scene listing"
  union :scene_or_scene_listing do
    types [:scene, :scene_listing]

    resolve_type fn
      %Scene{}, _ -> :scene
      %SceneListing{}, _ -> :scene_listing
      _, _ -> nil
    end
  end

  @desc "A scene"
  object :scene do
    @desc "The scene id"
    field :scene_sid, :id, name: "id"
    @desc "The scene name"
    field :name, :string
  end

  @desc "A scene listing (which allows the creator to change the underlying scene assets)"
  object :scene_listing do
    @desc "The scene listing id"
    field :scene_listing_sid, :id, name: "id"
    @desc "The scene listing name"
    field :name, :string
  end
end
