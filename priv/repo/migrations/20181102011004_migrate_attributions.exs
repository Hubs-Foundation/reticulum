defmodule Ret.Repo.Migrations.MigrateAttributions do
  use Ecto.Migration

  def up do
    execute("update scenes set attributions = json_build_object('extras', scenes.attribution)")
  end

  def down do
  end
end
