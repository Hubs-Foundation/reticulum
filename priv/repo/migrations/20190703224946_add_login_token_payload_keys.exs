defmodule Ret.Repo.Migrations.AddLoginTokenPayloadKeys do
  use Ecto.Migration

  def change do
    alter table("login_tokens") do
      add :payload_key, :string
    end
  end
end
