defmodule Ret.Repo.Migrations.AddInactiveToOwnedFileStateEnum do
  use Ecto.Migration
  @disable_ddl_transaction true

  def change do
    execute "ALTER TYPE ret0.owned_file_state ADD VALUE IF NOT EXISTS 'inactive'"
  end
end
