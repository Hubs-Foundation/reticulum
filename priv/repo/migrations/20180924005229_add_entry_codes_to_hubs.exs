defmodule Ret.Repo.Migrations.AddEntryCodesToHubs do
  use Ecto.Migration

  def change do
    alter table("hubs") do
      add :entry_code, :integer, null: true
      add :entry_code_expires_at, :utc_datetime, null: true
    end

    create unique_index(:hubs, [:entry_code])
  end
end
