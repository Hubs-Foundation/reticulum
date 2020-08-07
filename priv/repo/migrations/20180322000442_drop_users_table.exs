defmodule Ret.Repo.Migrations.DropUsersTable do
  @moduledoc false
  use Ecto.Migration

  def change do
    drop(table(:users))
  end
end
