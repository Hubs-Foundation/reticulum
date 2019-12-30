defmodule Ret.Repo.Migrations.DropUsersTable do
  use Ret.Migration

  def change do
    drop(table(:users, prefix: "ret0"))
  end
end
