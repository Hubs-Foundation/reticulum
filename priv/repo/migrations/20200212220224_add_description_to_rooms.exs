defmodule Ret.Repo.Migrations.AddDescriptionToRooms do
  use Ecto.Migration

  def change do
    alter table("hubs") do
      add :description, :string, size: 64_000
    end
  end
end
