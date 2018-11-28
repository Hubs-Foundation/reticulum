defmodule Ret.Repo.Migrations.AddAccountToRoomObjects do
  use Ecto.Migration

  def change do
    # Add default account record for existing room objects.
    %Ret.Account{account_id: 0} |> Ret.Repo.insert()

    alter table("room_objects") do
      add(:account_id, references(:accounts, column: :account_id), default: 0)
    end

    flush()

    alter table("room_objects") do
      modify(:account_id, :bigint, default: nil, null: false)
    end
  end
end
