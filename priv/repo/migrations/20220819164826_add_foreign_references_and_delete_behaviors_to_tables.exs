defmodule Ret.Repo.Migrations.AddForeignReferencesAndDeleteBehaviorToTables do
  use Ecto.Migration

  @missing_references [
    # table, foreign_table, column, on_delete_action
    {:hub_bindings, :hubs, :hub_id, :delete_all},
    {:hub_invites, :hubs, :hub_id, :delete_all},
    {:oauth_providers, :accounts, :account_id, :delete_all},
    {:web_push_subscriptions, :hubs, :hub_id, :delete_all}
  ]

  @missing_on_delete_action [
    # table, column, foreign_table, foreign_column, on_delete_action
    {:account_favorites, :account_id, :accounts, :account_id, :delete_all},
    {:account_favorites, :hub_id, :hubs, :hub_id, :delete_all},
    {:api_credentials, :account_id, :accounts, :account_id, :delete_all},
    {:hub_role_memberships, :account_id, :accounts, :account_id, :delete_all},
    {:hub_role_memberships, :hub_id, :hubs, :hub_id, :delete_all},
    {:hubs, :created_by_account_id, :accounts, :account_id, :delete_all},
    {:projects, :parent_scene_id, :scenes, :scene_id, :nilify_all},
    {:room_objects, :account_id, :accounts, :account_id, :delete_all},
    {:room_objects, :hub_id, :hubs, :hub_id, :delete_all},
    {:scenes, :parent_scene_id, :scenes, :scene_id, :nilify_all}
  ]

  def up do
    for {table, foreign_table, column, on_delete_action} <- @missing_references do
      add_foreign_reference(table, column, foreign_table, column, on_delete: on_delete_action)
    end

    for {table, column, foreign_table, foreign_column, on_delete_action} <- @missing_on_delete_action do
      execute_drop_foreign_constraint(table, column)

      add_foreign_reference(table, column, foreign_table, foreign_column, on_delete: on_delete_action)
    end
  end

  def down do
    for {table, _foreign_table, column, _on_delete_action} <- @missing_references do
      execute_drop_foreign_constraint(table, column)
    end

    for {table, column, foreign_table, foreign_column, _on_delete_action} <- @missing_on_delete_action do
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
