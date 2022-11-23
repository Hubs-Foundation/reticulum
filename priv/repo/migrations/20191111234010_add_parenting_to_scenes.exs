defmodule Ret.Repo.Migrations.AddParentingToScenes do
  use Ecto.Migration

  def change do
    alter table("scenes") do
      add :parent_scene_id, references(:scenes, column: :scene_id)
      add :parent_scene_listing_id, references(:scene_listings, column: :scene_listing_id)
    end

    alter table("projects") do
      add :scene_id, references(:scenes, column: :scene_id)
    end
  end
end
