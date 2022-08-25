defmodule Ret.Repo.Migrations.DeleteOrphanedDataFromTablesMissingReferences do
  @moduledoc """
  This migration prepares the database for the migration that immediately follows it.
  Here we delete orphaned data, where an administrator might have manually, and partially
  deleted records that were referenced by these tables. The following migration adds
  those references to ensure constraints going forward.
  """
  use Ecto.Migration

  @missing_references [
    # table, primary_key, foreign_table, column
    {:hub_bindings, :hub_binding_id, :hubs, :hub_id},
    {:hub_invites, :hub_invite_id, :hubs, :hub_id},
    {:oauth_providers, :oauth_provider_id, :accounts, :account_id},
    {:web_push_subscriptions, :web_push_subscription_id, :hubs, :hub_id}
  ]

  def up do
    for {table, primary_key, foreign_table, column} <- @missing_references do
      execute("
        delete from #{table}
        using #{table} as tt
        left join #{foreign_table} as ft
        on tt.#{column} = ft.#{column}
        where
          #{table}.#{primary_key} = tt.#{primary_key} and
          ft.#{column} is null
      ")
    end
  end

  def down do
    # Can't un-delete data!
  end
end
