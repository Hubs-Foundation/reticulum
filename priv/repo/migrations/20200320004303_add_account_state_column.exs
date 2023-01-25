defmodule Ret.Repo.Migrations.AddAccountStateColumn do
  use Ecto.Migration

  def change do
    Ret.Account.State.create_type()

    alter table("accounts") do
      add :state, :account_state, null: false, default: "enabled"
    end

    execute "select ret0_admin.create_or_replace_admin_view('accounts')"
  end
end
