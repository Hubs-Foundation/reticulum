defmodule Ret.Repo.Migrations.AddCreatedByToHubs do
  use Ecto.Migration

  def change do
    alter table("hubs") do
      add :created_by_account_id, references(:accounts, column: :account_id)
    end

    create index(:hubs, [:created_by_account_id])
  end
end
