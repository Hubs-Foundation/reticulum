defmodule Ret.Repo.Migrations.AddOwnersToHubs do
  use Ecto.Migration

  def change do
    alter table("hubs") do
      add(:account_id, references(:accounts, column: :account_id))
    end

    create(index(:hubs, [:account_id]))
  end
end
