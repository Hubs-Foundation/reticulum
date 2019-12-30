defmodule Ret.Repo.Migrations.AddLastActiveAt do
  use Ret.Migration

  def change do
    alter table("hubs") do
      add(:last_active_at, :utc_datetime, null: true)
    end

    create(index(:hubs, [:last_active_at]))
  end
end
