defmodule Ret.Repo.Migrations.CreateAssetTypeEnum do
  @moduledoc false
  use Ecto.Migration

  def up do
    Ret.Asset.Type.create_type()
  end

  def down do
    Ret.Asset.Type.drop_type()
  end
end
