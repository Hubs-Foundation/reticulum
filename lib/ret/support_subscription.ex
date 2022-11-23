defmodule Ret.SupportSubscription do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ret.{SupportSubscription, Repo}

  @schema_prefix "ret0"
  @primary_key {:support_subscription_id, :id, autogenerate: true}

  schema "support_subscriptions" do
    field :channel, :string
    field :identifier, :string

    timestamps()
  end

  def changeset(
        %SupportSubscription{} = subscription,
        params \\ %{}
      ) do
    subscription
    |> cast(params, [:identifier])
    |> validate_required([:identifier])
    |> validate_length(:identifier, min: 3, max: 64)
    # TODO more channels
    |> put_change(:channel, "slack")
  end

  def support_available? do
    SupportSubscription |> Repo.all() |> Enum.empty?() |> Kernel.not()
  end
end
