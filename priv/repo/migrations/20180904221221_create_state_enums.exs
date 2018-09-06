defmodule Ret.Repo.Migrations.CreateStateEnums do
  use Ecto.Migration

  def up do
    Ret.OwnedFile.State.create_type()
    Ret.Scene.State.create_type()
  end

  def down do
    Ret.OwnedFile.State.drop_type()
    Ret.Scene.State.drop_type()
  end
end
