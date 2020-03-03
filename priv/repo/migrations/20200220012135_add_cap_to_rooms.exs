defmodule Ret.Repo.Migrations.AddCapToRooms do
  use Ecto.Migration

  def change do
    alter table("hubs") do
      add(:member_cap, :integer, null: true, default: nil)
    end
  end
end
