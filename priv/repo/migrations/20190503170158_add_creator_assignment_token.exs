defmodule Ret.Repo.Migrations.AddCreatorAssignmentToken do
  use Ecto.Migration

  def change do
    alter table("hubs") do
      add :creator_assignment_token, :string
    end
  end
end
