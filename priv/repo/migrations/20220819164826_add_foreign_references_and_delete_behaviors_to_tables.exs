defmodule Ret.Repo.Migrations.AddForeignReferencesAndDeleteBehaviorToTables do
  use Ecto.Migration

  @missing_references [
    # table, foreign_table, column
    {:hub_bindings, :hubs, :hub_id},
    {:hub_invites, :hubs, :hub_id},
    {:oauth_providers, :accounts, :account_id},
    {:web_push_subscriptions, :hubs, :hub_id}
  ]

  @missing_on_delete_action [
    # table, column, foreign_table, foreign_column
    {:account_favorites, :account_id, :accounts, :account_id},
    {:api_credentials, :account_id, :accounts, :account_id},
    {:hub_role_memberships, :account_id, :accounts, :account_id},
    {:hub_role_memberships, :hub_id, :hubs, :hub_id},
    {:hubs, :created_by_account_id, :accounts, :account_id},
    {:room_objects, :account_id, :accounts, :account_id}
  ]

  def up do
    for {table, foreign_table, column} <- @missing_references do
      add_foreign_reference(table, column, foreign_table, column, on_delete: :delete_all)
    end

    for {table, column, foreign_table, foreign_column} <- @missing_on_delete_action do
      execute_drop_foreign_constraint(table, column)

      add_foreign_reference(table, column, foreign_table, foreign_column, on_delete: :delete_all)
    end
  end

  def down do
    for {table, _foreign_table, column} <- @missing_references do
      execute_drop_foreign_constraint(table, column)
    end

    for {table, column, foreign_table, foreign_column} <- @missing_on_delete_action do
      execute_drop_foreign_constraint(table, column)

      add_foreign_reference(table, column, foreign_table, foreign_column, on_delete: :nothing)
    end
  end

  defp execute_drop_foreign_constraint(table, column) do
    execute("alter table #{table} drop constraint #{table}_#{column}_fkey")
  end

  defp add_foreign_reference(table, column, foreign_table, foreign_column, on_delete: on_delete_action) do
    alter table(table) do
      modify(column, references(foreign_table, column: foreign_column, on_delete: on_delete_action))
    end
  end
end
