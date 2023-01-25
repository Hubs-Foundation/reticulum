defmodule Ret.Repo.Migrations.AddEmbeddedFlagToHubs do
  use Ecto.Migration

  def change do
    alter table("hubs") do
      add :embedded, :boolean, default: false
    end
  end
end
