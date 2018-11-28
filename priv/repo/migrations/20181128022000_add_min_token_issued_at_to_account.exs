defmodule Ret.Repo.Migrations.AddMinTokenIssuedAtToAccount do
  use Ecto.Migration

  def change do
    alter table("accounts") do
      add(:min_token_issued_at, :utc_datetime, default: Ecto.DateTime.from_unix!(0, :seconds) |> Ecto.DateTime.to_iso8601(), null: false)
    end
  end
end
