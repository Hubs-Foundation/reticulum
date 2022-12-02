defmodule Ret.Repo.Migrations.AddEmbedTokenToHubs do
  use Ecto.Migration

  def change do
    alter table("hubs") do
      add :embed_token, :string
    end
  end
end
