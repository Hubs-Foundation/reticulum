defmodule Ret.Repo.Migrations.AddSupportSubscriptionsTable do
  use Ecto.Migration

  def change do
    create table(:support_subscriptions, primary_key: false) do
      add(:support_subscription_id, :bigint,
        default: fragment("ret0.next_id()"),
        primary_key: true
      )

      add(:channel, :string, null: false)
      add(:identifier, :string, null: false)

      timestamps()
    end

    create(index(:support_subscriptions, [:channel, :identifier], unique: true))
  end
end
