defmodule Ret.Repo.Migrations.AddEntityCreateMessagesTable do
  use Ecto.Migration

  def change do
    create table(:entity_create_messages, primary_key: false) do
      add :entity_create_message_id, :bigint,
        default: fragment("ret0.next_id()"),
        primary_key: true

      add :nid, :string, null: false
      add :create_message, :binary, null: false
      add :hub_id, references(:hubs, column: :hub_id), null: false
      timestamps()
    end

    create unique_index(:entity_create_messages, [:nid, :hub_id])
    create index(:entity_create_messages, [:hub_id])
    create index(:entity_create_messages, [:nid])
  end
end
