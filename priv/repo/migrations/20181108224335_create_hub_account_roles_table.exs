defmodule Ret.Repo.Migrations.CreateHubAccountRolesTable do
  use Ecto.Migration

  def change do
    create table(:hub_account_roles, prefix: "ret0", primary_key: false) do
      add(:hub_account_role_id, :bigint, default: fragment("ret0.next_id()"), primary_key: true)
      add(:hub_id, references(:hubs, column: :hub_id), null: false)
      add(:account_id, references(:accounts, column: :account_id), null: false)
      add(:roles, :int, null: false, default: 0)

      timestamps()
    end

    create(index(:hub_account_roles, [:hub_id, :account_id], unique: true))
    create(index(:hub_account_roles, [:hub_id]))
  end
end
