defmodule Ret.Repo.Migrations.AddImportedFromColumns do
  use Ecto.Migration

  def change do
    alter table("avatars") do
      add(:imported_from_host, :string)
      add(:imported_from_port, :integer)
      add(:imported_from_sid, :string)
    end

    create(
      index(:avatars, [:imported_from_host, :imported_from_port, :imported_from_sid], unique: true)
    )

    alter table("scenes") do
      add(:imported_from_host, :string)
      add(:imported_from_port, :integer)
      add(:imported_from_sid, :string)
    end

    create(
      index(:scenes, [:imported_from_host, :imported_from_port, :imported_from_sid], unique: true)
    )
  end
end
