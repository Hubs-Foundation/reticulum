defmodule Ret.Repo.Migrations.AddAttributionsToScene do
  use Ret.Migration

  def change do
    alter table("scenes") do
      add(:attributions, :jsonb)
    end
  end
end
