defmodule Ret.Repo.Migrations.AddInviteToHubEntryModeEnum do
  use Ecto.Migration
  @disable_ddl_transaction true

  def change do
    execute "ALTER TYPE ret0.hub_entry_mode ADD VALUE IF NOT EXISTS 'invite'"
  end
end
