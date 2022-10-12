defmodule Ret.Repo.Migrations.AddHubsPublicRoomsIndex do
  use Ecto.Migration

  def change do
    create(index(:hubs, [:allow_promotion]))
  end
end
