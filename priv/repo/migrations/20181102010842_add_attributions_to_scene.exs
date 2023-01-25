defmodule Ret.Repo.Migrations.AddAttributionsToScene do
  use Ecto.Migration

  def change do
    alter table("scenes") do
      add :attributions, :jsonb
    end
  end
end
