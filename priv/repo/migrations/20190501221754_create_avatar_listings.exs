defmodule Ret.Repo.Migrations.CreateAvatarListings do
  use Ecto.Migration

  def change do
    Ret.AvatarListing.State.create_type()

    create table(:avatar_listings, primary_key: false) do
      add :avatar_listing_id, :bigint, default: fragment("ret0.next_id()"), primary_key: true
      add :avatar_listing_sid, :string, null: false
      add :slug, :string, null: false
      add :order, :integer
      add :state, :avatar_listing_state, null: false, default: "active"
      add :tags, :jsonb
      add :avatar_id, :bigint, null: false
      add :name, :string, null: false
      add :description, :string
      add :attributions, :jsonb
      add :parent_avatar_listing_id, references(:avatar_listings, column: :avatar_listing_id)
      add :gltf_owned_file_id, references(:owned_files, column: :owned_file_id)
      add :bin_owned_file_id, references(:owned_files, column: :owned_file_id)
      add :thumbnail_owned_file_id, references(:owned_files, column: :owned_file_id)
      add :base_map_owned_file_id, references(:owned_files, column: :owned_file_id)
      add :emissive_map_owned_file_id, references(:owned_files, column: :owned_file_id)
      add :normal_map_owned_file_id, references(:owned_files, column: :owned_file_id)
      add :orm_map_owned_file_id, references(:owned_files, column: :owned_file_id)

      timestamps()
    end

    create unique_index(:avatar_listings, [:avatar_listing_sid])

    alter table(:avatars) do
      add :parent_avatar_listing_id, references(:avatar_listings, column: :avatar_listing_id)
      add :reviewed_at, :utc_datetime, null: true
    end

    create index(:avatars, [:reviewed_at],
             where: "reviewed_at is null or reviewed_at < updated_at"
           )
  end
end
