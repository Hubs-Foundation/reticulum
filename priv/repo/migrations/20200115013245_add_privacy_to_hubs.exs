defmodule Ret.Repo.Migrations.AddPrivacyToHubs do
  use Ecto.Migration

  def change do
    Ret.Hub.Privacy.create_type()

    alter table(:hubs) do
      add(:privacy, :hub_privacy, null: false, default: "private")
    end
  end
end
