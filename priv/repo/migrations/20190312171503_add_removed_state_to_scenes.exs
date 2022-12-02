defmodule Ret.Repo.Migrations.AddRemovedStateToScenes do
  use Ecto.Migration
  @disable_ddl_transaction true

  def change do
    execute "ALTER TYPE ret0.scene_state ADD VALUE IF NOT EXISTS 'removed'"
  end
end
