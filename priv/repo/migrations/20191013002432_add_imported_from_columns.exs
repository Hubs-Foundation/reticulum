defmodule Ret.Repo.Migrations.AddImportedFromColumns do
  use Ecto.Migration

  def change do
    alter table("avatars") do
      add :imported_from_host, :string
      add :imported_from_port, :integer
      add :imported_from_sid, :string
    end

    create unique_index(:avatars, [:imported_from_host, :imported_from_port, :imported_from_sid])

    alter table("scenes") do
      add :imported_from_host, :string
      add :imported_from_port, :integer
      add :imported_from_sid, :string
    end

    create unique_index(:scenes, [:imported_from_host, :imported_from_port, :imported_from_sid])
  end
end
