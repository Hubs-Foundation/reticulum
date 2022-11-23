defmodule Ret.Repo.Migrations.CreateHubRoleMemberships do
  use Ecto.Migration

  def change do
    create table(:hub_role_memberships, primary_key: false) do
      add :hub_role_membership_id, :bigint, default: fragment("ret0.next_id()"), primary_key: true
      add :hub_id, references(:hubs, column: :hub_id)
      add :account_id, references(:accounts, column: :account_id), null: false

      # Right now role membership is implicit to be the single role of "owners", no db state for now in accordance with YAGNI

      timestamps()
    end

    create unique_index(:hub_role_memberships, [:hub_id, :account_id])
  end
end
