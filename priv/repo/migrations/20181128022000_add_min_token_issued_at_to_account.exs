defmodule Ret.Repo.Migrations.AddMinTokenIssuedAtToAccount do
  use Ecto.Migration

  def change do
    epoch = DateTime.from_unix!(0, :second) |> DateTime.truncate(:second) |> DateTime.to_iso8601()

    alter table("accounts") do
      add :min_token_issued_at, :utc_datetime, default: epoch, null: false
    end
  end
end
