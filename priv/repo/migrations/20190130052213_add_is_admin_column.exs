defmodule Ret.Repo.Migrations.AddIsAdminColumn do
  use Ecto.Migration

  def change do
    alter table("accounts") do
      add :is_admin, :boolean
    end
  end
end
