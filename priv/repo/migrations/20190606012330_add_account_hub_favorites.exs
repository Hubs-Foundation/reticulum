defmodule Ret.Repo.Migrations.AddAccountHubFavorites do
  use Ecto.Migration

  def change do
    create table(:account_hub_favorites, prefix: "ret0", primary_key: false) do
      add(:account_hub_favorite_id, :bigint, default: fragment("ret0.next_id()"), primary_key: true)
      add(:account_id, references(:accounts, column: :account_id), null: false)
      add(:hub_id, references(:accounts, column: :account_id), null: false)
      add(:last_joined_at, :utc_datetime)

      timestamps()
    end

    # Do not create inverted index on hubs, because that will lead to bad access
    # patterns if/when we need to shard this table.
    create(index(:account_hub_favorites, [:account_id, :hub_id], unique: true))
  end
end
