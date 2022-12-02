defmodule Ret.Repo.Migrations.CreateIdentitiesAdmin do
  use Ecto.Migration

  def up do
    execute "select ret0_admin.create_or_replace_admin_view('identities', ',cast(account_id as varchar) as _account_id')"

    execute "grant select, insert, update, delete on ret0_admin.identities to ret_admin"
  end

  def down do
    execute "drop view ret0_admin.identities"
  end
end
