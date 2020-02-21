defmodule Ret.Repo.Migrations.AddCapToRooms do
  use Ecto.Migration

  def change do
    alter table("hubs") do
      add(:member_cap, :integer, null: false, default: 0)
    end
  end
end
