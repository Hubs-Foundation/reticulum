defmodule Ret.Repo.Migrations.AddInactiveToOwnedFileStateEnum do
  use Ret.Migration
  @disable_ddl_transaction true

  def change do
    Ecto.Migration.execute("ALTER TYPE owned_file_state ADD VALUE IF NOT EXISTS 'inactive'")
  end
end
