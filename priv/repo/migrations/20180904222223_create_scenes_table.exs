defmodule Ret.Repo.Migrations.CreateScenesTable do
  use Ecto.Migration

  def change do
    create table(:scenes, primary_key: false) do
      add :scene_id, :bigint, default: fragment("ret0.next_id()"), primary_key: true
      add :scene_sid, :string
      add :slug, :string, null: false
      add :name, :string, null: false
      add :description, :string
      add :account_id, :bigint, null: false
      add :model_owned_file_id, :bigint, null: false
      add :screenshot_owned_file_id, :bigint, null: false
      add :state, :scene_state, null: false, default: "active"

      timestamps()
    end

    create unique_index(:scenes, [:scene_sid])
    create index(:scenes, [:account_id])
  end
end
