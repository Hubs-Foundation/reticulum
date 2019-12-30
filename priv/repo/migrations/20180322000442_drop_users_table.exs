defmodule Ret.Repo.Migrations.DropUsersTable do
  use Ecto.Migration

  def change do
    drop(table(:users, prefix: "ret0"))
  end
end
