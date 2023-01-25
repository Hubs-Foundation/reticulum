defmodule Ret.Repo.Migrations.AddThumbnailToAvatar do
  use Ecto.Migration

  def change do
    alter table(:avatars) do
      add :thumbnail_owned_file_id, references(:owned_files, column: :owned_file_id)
    end
  end
end
