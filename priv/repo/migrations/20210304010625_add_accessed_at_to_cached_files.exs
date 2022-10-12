defmodule Ret.Repo.Migrations.AddAccessedAtToCachedFiles do
  use Ecto.Migration

  def change do
    alter table(:cached_files) do
      add(:accessed_at, :naive_datetime, null: false, default: fragment("now()"))
    end
  end
end
