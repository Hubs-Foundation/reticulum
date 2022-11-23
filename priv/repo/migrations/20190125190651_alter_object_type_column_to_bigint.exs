defmodule Ret.Repo.Migrations.AlterObjectTypeColumnToBigint do
  use Ecto.Migration

  def change do
    alter table("hubs") do
      modify :spawned_object_types, :bigint
    end
  end
end
