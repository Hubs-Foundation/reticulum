defmodule Ret.Repo.Migrations.CreateScenes do
  use Ecto.Migration

  def change do
    create table(:scenes, prefix: "ret0", primary_key: false) do
      add :scene_id, :bigint, default: fragment("ret0.next_id()"), primary_key: true
      add :scene_sid, :string
      add :slug, :string, null: false
      add :name, :string, null: false
      add :description, :string
      add :author_account_id, :integer, null: false
      add :upload_id, :integer, null: false
      add :attribution_name, :string, null: false
      add :attribution_link, :string
      add :derived_from_scene_id, :integer

      timestamps()
    end

    create index(:scenes, [:scene_sid], unique: true)
  end
end
