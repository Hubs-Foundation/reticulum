defmodule Ret.Repo.Migrations.AddForeignReferencesAndDeleteBehaviorToTables do
  use Ecto.Migration

  @missing_reference [
    {:hub_bindings, :hub_id, :hubs},
    {:hub_invites, :hub_id, :hubs},
    {:oauth_providers, :account_id, :accounts},
    {:web_push_subscriptions, :hub_id, :hubs}
  ]

  @missing_on_delete_action [
    {:account_favorites, :account_id, :accounts, :account_id},
    {:account_favorites, :hub_id, :hubs, :hub_id},
    {:api_credentials, :account_id, :accounts, :account_id},
    {:hub_role_memberships, :account_id, :accounts, :account_id},
    {:hub_role_memberships, :hub_id, :hubs, :hub_id},
    {:hubs, :created_by_account_id, :accounts, :account_id},
    {:hubs, :scene_id, :scenes, :scene_id},
    {:room_objects, :account_id, :accounts, :account_id},
    {:room_objects, :hub_id, :hubs, :hub_id},
    {:scenes, :parent_scene_id, :scenes, :scene_id}
  ]

  def up do
    for {table, column, foreign_table} <- @missing_reference do
      alter table(table) do
        modify column, references(foreign_table, column: column, on_delete: :delete_all)
      end
    end

    for {table, column, foreign_table, foreign_column} <- @missing_on_delete_action do
      drop_foreign_constraint(table, column)

      alter table(table) do
        modify column, references(foreign_table, column: foreign_column, on_delete: :delete_all)
      end
    end
  end

  def down do
    for {table, column, _foreign_table} <- @missing_reference do
      drop_foreign_constraint(table, column)
    end

    for {table, column, foreign_table, foreign_column} <- @missing_on_delete_action do
      drop_foreign_constraint(table, column)

      alter table(table) do
        modify column, references(foreign_table, column: foreign_column, on_delete: :nothing)
      end
    end
  end

  @spec drop_foreign_constraint(String.t(), String.t()) :: :ok
  defp drop_foreign_constraint(table, column) when is_atom(table) and is_atom(column) do
    execute "ALTER TABLE #{table} DROP CONSTRAINT #{table}_#{column}_fkey"
  end
end
