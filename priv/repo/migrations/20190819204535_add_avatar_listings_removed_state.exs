defmodule Ret.Repo.Migrations.AddAvatarListingsRemovedState do
  use Ecto.Migration
  @disable_ddl_transaction true

  def change do
    Ecto.Migration.execute("ALTER TYPE avatar_listing_state ADD VALUE IF NOT EXISTS 'removed'")
  end
end
