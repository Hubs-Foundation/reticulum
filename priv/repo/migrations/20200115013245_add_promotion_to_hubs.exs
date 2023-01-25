defmodule Ret.Repo.Migrations.AddPromotionToHubs do
  use Ecto.Migration

  def change do
    alter table(:hubs) do
      add :allow_promotion, :boolean, null: false, default: false
    end
  end
end
