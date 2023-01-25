defmodule Ret.Repo.Migrations.CreateAccount do
  use Ecto.Migration

  def change do
    create table(:accounts, primary_key: false) do
      add :account_id, :bigint, default: fragment("ret0.next_id()"), primary_key: true

      timestamps()
    end
  end
end
