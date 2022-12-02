defmodule Ret.Repo.Migrations.AddHubBindingsTable do
  use Ecto.Migration

  def change do
    Ret.HubBinding.Type.create_type()

    create table(:hub_bindings, primary_key: false) do
      add :hub_binding_id, :bigint, default: fragment("ret0.next_id()"), primary_key: true
      add :hub_id, :bigint, null: false
      add :type, :hub_binding_type, null: false
      add :community_id, :string, null: false
      add :channel_id, :string, null: false

      timestamps()
    end

    create unique_index(:hub_bindings, [:type, :community_id, :channel_id])
  end
end
