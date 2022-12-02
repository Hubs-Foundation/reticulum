defmodule Ret.Repo.Migrations.AddSceneListingIdToHubs do
  use Ecto.Migration

  def change do
    alter table("hubs") do
      add :scene_listing_id, references(:scene_listings, column: :scene_listing_id)
    end
  end
end
