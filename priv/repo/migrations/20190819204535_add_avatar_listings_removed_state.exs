defmodule Ret.Repo.Migrations.AddAvatarListingsRemovedState do
  use Ecto.Migration
  import Ecto.Query
  alias Ret.{AvatarListing}

  @disable_ddl_transaction true

  def up do
    Ecto.Migration.execute(
      "ALTER TYPE ret0.avatar_listing_state ADD VALUE IF NOT EXISTS 'removed'"
    )

    flush()

    repo().update_all(
      from(l in AvatarListing, where: l.state == ^:delisted and not is_nil(l.avatar_id)),
      set: [state: :removed]
    )
  end

  def down do
    # There is no great way to reverse this migration, so we would probably need to manually decide what to do
  end
end
