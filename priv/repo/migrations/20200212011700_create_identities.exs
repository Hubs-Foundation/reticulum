defmodule Ret.Repo.Migrations.CreateIdentities do
  use Ecto.Migration

  def change do
    create table(:identities, primary_key: false) do
      add :identity_id, :bigint, default: fragment("ret0.next_id()"), primary_key: true
      add :name, :string, null: false
      add :account_id, references(:accounts, column: :account_id, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:identities, [:account_id])
  end
end
