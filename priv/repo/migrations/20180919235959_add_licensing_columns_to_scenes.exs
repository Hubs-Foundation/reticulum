defmodule Ret.Repo.Migrations.AddLicensingColumnsToScenes do
  use Ecto.Migration

  def change do
    alter table("scenes") do
      add :allow_remixing, :boolean, null: false, default: false
      add :allow_promotion, :boolean, null: false, default: false
      add :scene_owned_file_id, references(:owned_files, column: :owned_file_id)
    end
  end
end
