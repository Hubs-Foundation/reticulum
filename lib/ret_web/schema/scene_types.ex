defmodule RetWeb.Schema.SceneTypes do
  use Absinthe.Schema.Notation
  alias Ret.{Scene, SceneListing}

  union :scene_or_scene_listing do
    types [:scene, :scene_listing]
    resolve_type fn
      %Scene{}, _ -> :scene
      %SceneListing{}, _ -> :scene_listing
    end
  end

  object :scene do
    field(:scene_sid, :id, name: "id")
    field(:name, :string)
  end

  object :scene_listing do
    field(:scene_listing_sid, :id, name: "id")
    field(:name, :string)
  end
end
