defmodule Ret.Repo.Migrations.AddCapToRooms do
  use Ecto.Migration

  def change do
    alter table("hubs") do
      add :room_size, :integer, null: true, default: nil
    end
  end
end
