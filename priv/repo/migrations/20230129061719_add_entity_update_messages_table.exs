defmodule Ret.Repo.Migrations.AddEntityUpdateMessagesTable do
  use Ecto.Migration

  def change do
    create table(:entity_update_messages, primary_key: false) do
      add :entity_update_message_id, :bigint,
        default: fragment("ret0.next_id()"),
        primary_key: true

      add :nid, :string, null: false
      add :update_message, :binary, null: false
      add :hub_id, references(:hubs, column: :hub_id), null: false

      add :entity_create_message_id,
          references(:entity_create_messages, column: :entity_create_message_id),
          null: false

      timestamps()
    end

    create unique_index(:entity_update_messages, [:nid, :hub_id])
    create index(:entity_update_messages, [:hub_id])
    create index(:entity_update_messages, [:nid])
  end
end
