defmodule Ret.Repo.Migrations.AddEmbedTokenToHubs do
  use Ecto.Migration

  def change do
    alter table("login_tokens") do
      add(:payload_key, :string)
    end
  end
end
