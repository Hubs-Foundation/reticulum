defmodule Ret.Repo.Migrations.UpdateAvatarConstraints do
  use Ecto.Migration

  def up do
    drop constraint(:avatars, :gltf_or_parent)

    create constraint(:avatars, :gltf_or_parent_or_parent_listing,
             check:
               "parent_avatar_id is not null or parent_avatar_listing_id is not null or (gltf_owned_file_id is not null and bin_owned_file_id is not null)"
           )
  end

  def down do
    drop constraint(:avatars, :gltf_or_parent_or_parent_listing)

    create constraint(:avatars, :gltf_or_parent,
             check:
               "parent_avatar_id is not null or (gltf_owned_file_id is not null and bin_owned_file_id is not null)"
           )
  end
end
