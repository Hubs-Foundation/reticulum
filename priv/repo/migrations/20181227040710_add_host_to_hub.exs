defmodule Ret.Repo.Migrations.AddHostToHub do
  use Ecto.Migration

  def change do
    alter table("hubs") do
      add(:host, :string)
    end
  end
end
