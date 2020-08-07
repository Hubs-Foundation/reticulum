defmodule Ret.Repo.Migrations.DropNullConstraintOnAssetThumbnail do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table("assets") do
      modify(:thumbnail_owned_file_id, :bigint, null: true)
    end
  end
end
