defmodule Ret.Repo.Migrations.AddEntryModeToHub do
  use Ecto.Migration

  def up do
    Ret.Hub.EntryMode.create_type()

    alter table("hubs") do
      add :entry_mode, :hub_entry_mode, null: false, default: "allow"
    end
  end

  def down do
    alter table("hubs") do
      remove :entry_mode
    end

    Ret.Hub.EntryMode.drop_type()
  end
end
