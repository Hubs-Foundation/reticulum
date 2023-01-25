defmodule Ret.Repo.Migrations.AddAudioAssetType do
  use Ecto.Migration
  @disable_ddl_transaction true

  def change do
    execute "ALTER TYPE ret0.asset_type ADD VALUE IF NOT EXISTS 'audio'"
  end
end
