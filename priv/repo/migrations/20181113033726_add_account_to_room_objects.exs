defmodule Ret.Repo.Migrations.AddAccountToRoomObjects do
  use Ecto.Migration

  def change do
    alter table("room_objects") do
      add(:account_id, references(:accounts, column: :account_id))
    end

    create(
      constraint(
        "room_objects",
        "room_object_is_legacy_or_has_account",
        check:
          "inserted_at < '#{DateTime.utc_now() |> DateTime.to_iso8601()}' or account_id is not null"
      )
    )
  end
end
