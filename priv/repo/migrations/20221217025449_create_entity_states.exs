defmodule Ret.Repo.Migrations.CreateEntityStates do
  use Ecto.Migration

  def change do
    create table(:entity_states, primary_key: false) do
      add :entity_state_id, :bigint, default: fragment("ret0.next_id()"), primary_key: true
      add :root_nid, :string, null: false
      add :nid, :string, null: false
      add :hub_id, references(:hubs, column: :hub_id), null: false
      add :message, :binary
      timestamps()
    end

    create unique_index(:entity_states, [:nid, :hub_id])
    create index(:entity_states, [:hub_id])
    create index(:entity_states, [:root_nid])
  end
end
