defmodule Ret.Repo.Migrations.CreateStorageStats do
  use Ecto.Migration

  def change do
    create table(:storage_stats) do
      add(:node_id, :binary)
      add(:measured_at, :utc_datetime)
      add(:present_storage_blocks, :integer)

      timestamps()
    end
  end
end
