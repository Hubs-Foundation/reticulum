defmodule Ret.Repo.Migrations.AddDescriptionToRooms do
  use Ecto.Migration

  def change do
    alter table("hubs") do
      add(:description, :text)
    end
  end
end
