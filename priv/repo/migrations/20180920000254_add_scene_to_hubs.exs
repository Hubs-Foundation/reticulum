defmodule Ret.Repo.Migrations.AddSceneToHubs do
  use Ecto.Migration

  def change do
    alter table("hubs") do
      add :scene_id, references(:scenes, column: :scene_id)
    end
  end
end
