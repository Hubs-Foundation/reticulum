defmodule Ret.Repo.Migrations.AddRemovedStateToScenes do
  use Ret.Migration
  @disable_ddl_transaction true

  def change do
    Ecto.Migration.execute("ALTER TYPE scene_state ADD VALUE IF NOT EXISTS 'removed'")
  end
end
