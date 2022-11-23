defmodule Ret.Repo.Migrations.CreateAssetsTables do
  use Ecto.Migration

  def change do
    create table(:assets, primary_key: false) do
      add :asset_id, :bigint, default: fragment("ret0.next_id()"), primary_key: true
      add :asset_sid, :string, null: false
      add :name, :string, null: false
      add :type, :asset_type, null: false
      add :account_id, references(:accounts, column: :account_id), null: false
      add :asset_owned_file_id, :bigint, null: false
      add :thumbnail_owned_file_id, :bigint, null: false

      timestamps()
    end

    create unique_index(:assets, [:asset_sid])
    create index(:assets, [:account_id])

    create table(:project_assets, primary_key: false) do
      add :project_asset_id, :bigint, default: fragment("ret0.next_id()"), primary_key: true

      add :project_id, references(:projects, column: :project_id, on_delete: :delete_all),
        primary_key: true

      add :asset_id, references(:assets, column: :asset_id, on_delete: :delete_all),
        primary_key: true

      timestamps()
    end

    create index(:project_assets, [:project_id])
    create index(:project_assets, [:asset_id])

    create unique_index(:project_assets, [:project_id, :asset_id],
             name: :project_id_asset_id_unique_index
           )
  end
end
