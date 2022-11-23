defmodule Ret.Repo.Migrations.AddWebPushSubscriptions do
  use Ecto.Migration

  def change do
    create table(:web_push_subscriptions, primary_key: false) do
      add(:web_push_subscription_id, :bigint,
        default: fragment("ret0.next_id()"),
        primary_key: true
      )

      add(:p256dh, :string, null: false)
      add(:endpoint, :string, null: false)
      add(:auth, :binary, null: false)
      add(:hub_id, :bigint, null: false)
      add(:last_notified_at, :utc_datetime, null: true)

      timestamps()
    end

    create(index(:web_push_subscriptions, [:hub_id, :endpoint], unique: true))
    create(index(:web_push_subscriptions, [:endpoint]))
  end
end
