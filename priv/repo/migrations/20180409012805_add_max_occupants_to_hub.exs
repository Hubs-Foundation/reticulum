defmodule Ret.Repo.Migrations.AddMaxOccupantsToHub do
  use Ecto.Migration

  def change do
    alter table("hubs") do
      add :max_occupant_count, :integer, null: false, default: 0
    end
  end
end
