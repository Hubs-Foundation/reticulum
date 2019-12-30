defmodule Ret.Repo.Migrations.AddEmbedTokenToHubs do
  use Ret.Migration

  def change do
    alter table("hubs") do
      add(:embed_token, :string)
    end
  end
end
