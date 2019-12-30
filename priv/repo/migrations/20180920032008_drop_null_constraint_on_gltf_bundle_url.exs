defmodule Ret.Repo.Migrations.DropNullConstraintOnGltfBundleUrl do
  use Ret.Migration

  def change do
    alter table("hubs") do
      modify(:default_environment_gltf_bundle_url, :string, null: true)
    end
  end
end
