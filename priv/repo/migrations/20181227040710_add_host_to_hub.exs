defmodule Ret.Repo.Migrations.AddHostToHub do
  use Ecto.Migration

  def change do
    alter table("hubs") do
      add :host, :string
    end

    create index(:hubs, [:host, :inserted_at], where: "host is not null")
  end
end
