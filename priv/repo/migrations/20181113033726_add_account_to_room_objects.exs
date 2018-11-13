defmodule Ret.Repo.Migrations.AddAccountToRoomObjects do
  use Ecto.Migration

  def change do
    alter table("room_objects") do
      add(:account_id, references(:accounts, column: :account_id))
    end
  end
end
