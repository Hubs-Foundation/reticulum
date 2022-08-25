defmodule Ret.Repo.Migrations.AddAccountReferencesAndDeleteBehaviorToTables do
  use Ecto.Migration

  def change do
    alter table(:oauth_providers) do
      modify(:account_id, references(:accounts, column: :account_id, on_delete: :delete_all))
    end

    execute("alter table api_credentials drop constraint api_credentials_account_id_fkey")

    alter table(:api_credentials) do
      modify(:account_id, references(:accounts, column: :account_id, on_delete: :delete_all))
    end
  end
end
