defmodule Ret.Repo.Migrations.CreateStateEnums do
  use Ecto.Migration

  def up do
    Ret.StoredFile.State.create_type()
    Ret.Scene.State.create_type()
  end

  def down do
    Ret.StoredFile.State.drop_type()
    Ret.Scene.State.drop_type()
  end
end
