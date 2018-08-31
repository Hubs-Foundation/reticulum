defmodule Ret.Repo.Migrations.CreateLogin do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION citext SCHEMA public", "DROP EXTENSION citext")

    create table(:logins, prefix: "ret0", primary_key: false) do
      add(:login_id, :bigint, default: fragment("ret0.next_id()"), primary_key: true)
      add(:email, :citext, null: false)
      add(:account_id, references(:accounts, column: :account_id, on_delete: :delete_all))

      timestamps()
    end

    create(index(:logins, [:email], unique: true))
    create(index(:logins, [:account_id]))
  end
end
