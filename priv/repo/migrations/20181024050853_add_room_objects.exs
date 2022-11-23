defmodule Ret.Repo.Migrations.CreateRoomObjectsTable do
  use Ecto.Migration

  def change do
    create table(:room_objects, primary_key: false) do
      add :room_object_id, :bigint, default: fragment("ret0.next_id()"), primary_key: true
      add :object_id, :string, null: false
      add :hub_id, references(:hubs, column: :hub_id), null: false
      add :gltf_node, :binary, null: false

      timestamps()
    end

    create unique_index(:room_objects, [:object_id, :hub_id])
    create index(:room_objects, [:hub_id])
  end
end
