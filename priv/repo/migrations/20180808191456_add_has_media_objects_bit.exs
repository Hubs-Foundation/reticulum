defmodule Ret.Repo.Migrations.AddHasMediaObjectsBit do
  use Ecto.Migration

  def change do
    alter table("hubs") do
      add :spawned_object_types, :int, null: false, default: 0
    end
  end
end
