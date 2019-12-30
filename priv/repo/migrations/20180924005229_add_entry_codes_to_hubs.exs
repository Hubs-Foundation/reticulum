defmodule Ret.Repo.Migrations.AddEntryCodesToHubs do
  use Ecto.Migration

  def change do
    alter table("hubs") do
      add(:entry_code, :integer, null: true)
      add(:entry_code_expires_at, :utc_datetime, null: true)
    end

    create(index(:hubs, [:entry_code], unique: true))
  end
end
