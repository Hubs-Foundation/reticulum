defmodule Ret.Repo.Migrations.AddAccountDisabledColumn do
  use Ecto.Migration

  def change do
    alter table("accounts") do
      add(:disabled, :boolean)
    end

    execute("select ret0_admin.create_or_replace_admin_view('accounts');")
  end
end
