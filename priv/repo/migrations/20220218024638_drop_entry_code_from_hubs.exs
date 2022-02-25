defmodule Ret.Repo.Migrations.DropEntryCodeFromHubs do
  use Ecto.Migration

  def change do
    drop(index(:hubs, [:entry_code]))

    alter table("hubs") do
      remove(:entry_code)
      remove(:entry_code_expires_at)
    end
  end
end
