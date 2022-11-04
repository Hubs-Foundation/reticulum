defmodule Ret.Repo.Migrations.DeleteOrphanedDataFromTablesMissingReferences do
  @moduledoc """
  This migration prepares the database for the migration that immediately follows it.
  Here we delete orphaned data, where an administrator might have manually, and partially
  deleted records that were referenced by these tables. The following migration adds
  those references to ensure constraints going forward.
  """
  use Ecto.Migration

  def up do
    for {table, column, foreign_table} <- [
          {:hub_bindings, :hub_id, :hubs},
          {:hub_invites, :hub_id, :hubs},
          {:oauth_providers, :account_id, :accounts},
          {:web_push_subscriptions, :hub_id, :hubs}
        ] do
      execute("""
      DELETE FROM #{table}
      WHERE NOT EXISTS
        (SELECT *
           FROM "#{foreign_table}"
          WHERE "#{table}"."#{column}" = "#{foreign_table}"."#{column}")
      """)
    end
  end

  def down do
  end
end
