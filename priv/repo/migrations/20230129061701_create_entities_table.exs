defmodule Ret.Repo.Migrations.CreateEntitiesTable do
  use Ecto.Migration

  def change do
    create table(:entities, primary_key: false) do
      add :entity_id, :bigint,
        default: fragment("ret0.next_id()"),
        primary_key: true

      add :nid, :string, null: false
      add :create_message, :binary, null: false
      add :hub_id, references(:hubs, column: :hub_id), null: false
      timestamps()
    end

    create unique_index(:entities, [:nid, :hub_id])
    create index(:entities, [:hub_id])
    create index(:entities, [:nid])
  end
end
