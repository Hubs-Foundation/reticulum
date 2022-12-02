defmodule Ret.Repo.Migrations.AddReviewedAtToScenes do
  use Ecto.Migration

  def change do
    alter table("scenes") do
      add :reviewed_at, :utc_datetime, null: true
    end

    create index(:scenes, [:reviewed_at], where: "reviewed_at is null or reviewed_at < updated_at")
  end
end
