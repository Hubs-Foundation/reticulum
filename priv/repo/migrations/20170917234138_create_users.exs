defmodule Ret.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :user_id, :bigint, default: fragment("ret0.next_id()"), primary_key: true
      add :email, :string, null: false
      add :auth_provider, :string, null: false
      add :name, :string
      add :first_name, :string
      add :last_name, :string
      add :image, :string

      timestamps()
    end

    create unique_index(:users, [:email])
  end
end
