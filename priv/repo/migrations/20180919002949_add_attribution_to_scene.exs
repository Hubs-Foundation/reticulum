defmodule Ret.Repo.Migrations.AddAttributionToScene do
  use Ret.Migration

  def change do
    alter table("scenes") do
      add(:attribution, :string)
    end
  end
end
