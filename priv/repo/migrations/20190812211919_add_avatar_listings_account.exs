defmodule Ret.Repo.Migrations.AddAvatarListingsAccount do
  use Ecto.Migration
  import Ecto.Query

  alias Ret.{Avatar}

  def up do
    alter table(:avatar_listings) do
      add :account_id, references(:accounts, column: :account_id, null: false)
    end

    execute "ALTER TABLE ret0.avatar_listings ALTER COLUMN avatar_id DROP NOT NULL"

    create constraint(:avatar_listings, :avatar_required_for_listed,
             check: "avatar_id is not null or (avatar_id is null and state = 'delisted')"
           )

    flush()

    query =
      from l in "avatar_listings",
        join: a in Avatar,
        on: a.avatar_id == l.avatar_id,
        update: [set: [account_id: a.account_id]]

    repo().update_all(query, [])
  end

  def down do
    alter table(:avatar_listings) do
      remove :account_id
    end

    drop constraint(:avatar_listings, :avatar_required_for_listed)

    execute "ALTER TABLE ret0.avatar_listings ALTER COLUMN avatar_id SET NOT NULL"
  end
end
