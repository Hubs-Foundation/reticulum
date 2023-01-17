defmodule Ret.Repo.Migrations.GrantAdminDeleteOnProjects do
  use Ecto.Migration

  def change do
    execute "GRANT DELETE ON ret0_admin.projects TO ret_admin",
            "REVOKE DELETE ON ret0_admin.projects TO ret_admin"
  end
end
