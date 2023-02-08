defmodule Ret.Repo.Migrations.CreateSubEntitiesTable do
  use Ecto.Migration

  def change do
    create table(:sub_entities, primary_key: false) do
      add :sub_entity_id, :bigint,
        default: fragment("ret0.next_id()"),
        primary_key: true

      add :nid, :string, null: false
      add :update_message, :binary, null: false
      add :hub_id, references(:hubs, column: :hub_id), null: false

      add :entity_id, references(:entities, column: :entity_id, on_delete: :delete_all),
        null: false

      timestamps()
    end

    create unique_index(:sub_entities, [:nid, :hub_id])
    create index(:sub_entities, [:hub_id])
    create index(:sub_entities, [:nid])
  end
end
