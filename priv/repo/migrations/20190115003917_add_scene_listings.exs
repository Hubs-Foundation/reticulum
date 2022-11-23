defmodule Ret.Repo.Migrations.AddSceneListings do
  use Ecto.Migration

  def change do
    Ret.SceneListing.State.create_type()

    create table(:scene_listings, primary_key: false) do
      add :scene_listing_id, :bigint, default: fragment("ret0.next_id()"), primary_key: true
      add :scene_listing_sid, :string
      add :scene_id, :bigint, null: false
      add :slug, :string, null: false
      add :name, :string, null: false
      add :description, :string
      add :attributions, :jsonb
      add :tags, :jsonb
      add :model_owned_file_id, :bigint, null: false
      add :scene_owned_file_id, :bigint, null: false
      add :screenshot_owned_file_id, :bigint, null: false
      add :order, :integer
      add :state, :scene_listing_state, null: false, default: "active"

      timestamps()
    end

    create unique_index(:scene_listings, [:scene_listing_sid])
  end
end
