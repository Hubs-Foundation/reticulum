defmodule Ret.Repo.Migrations.AddPermissionsToHubs do
  use Ecto.Migration

  def change do
    alter table("hubs") do
      add(:permissions, :integer)
    end
  end
end
