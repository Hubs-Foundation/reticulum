defmodule Ret.Repo.Migrations.AddPermissionsToHubs do
  use Bitwise
  use Ecto.Migration

  def change do
    alter table("hubs") do
      add(:member_permissions, :integer, default: (1 <<< 4) - 1)
    end
  end
end
