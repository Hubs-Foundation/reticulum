defmodule Ret.Repo.Migrations.AddAttributionToScene do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table("scenes") do
      add(:attribution, :string)
    end
  end
end
