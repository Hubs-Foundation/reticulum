defmodule Ret.Repo.Migrations.AddLoginTokenPayloadKeys do
  use Ret.Migration

  def change do
    alter table("login_tokens") do
      add(:payload_key, :string)
    end
  end
end
