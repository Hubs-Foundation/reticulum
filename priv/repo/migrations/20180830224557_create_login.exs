defmodule Ret.Repo.Migrations.CreateLogin do
  use Ecto.Migration

  def change do
    create table(:logins, prefix: "ret0", primary_key: false) do
      add(:login_id, :bigint, default: fragment("ret0.next_id()"), primary_key: true)
      add(:identifier_hash, :string, null: false)
      add(:account_id, references(:accounts, column: :account_id, on_delete: :delete_all))

      timestamps()
    end

    create(index(:logins, [:identifier_hash], unique: true))
    create(index(:logins, [:account_id], unique: true))
  end
end
