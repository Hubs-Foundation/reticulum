defmodule Ret.WebPushSubscription do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  use Retry

  alias Ret.{EncryptedField, Hub, Repo, Statix, WebPushSubscription}

  @schema_prefix "ret0"
  @primary_key {:web_push_subscription_id, :id, autogenerate: true}
  @push_rate_limit_seconds 60

  schema "web_push_subscriptions" do
    field :p256dh, :string
    field :endpoint, :string
    field :auth, EncryptedField
    field :last_notified_at, :utc_datetime

    belongs_to :hub, Hub, references: :hub_id

    timestamps()
  end

  def subscribe_to_hub(
        %Hub{hub_id: hub_id} = hub,
        %{"endpoint" => endpoint, "keys" => %{"p256dh" => p256dh, "auth" => auth}} = subscription
      ) do
    find_by_hub_id_and_subscription(hub_id, subscription) ||
      %WebPushSubscription{}
      |> changeset_for_new(hub, %{p256dh: p256dh, auth: auth, endpoint: endpoint})
      |> Repo.insert!()
  end

  def unsubscribe_from_hub(
        %Hub{hub_id: hub_id},
        subscription
      ) do
    with %WebPushSubscription{} = web_push_subscription <-
           find_by_hub_id_and_subscription(hub_id, subscription) do
      web_push_subscription |> Repo.delete!()
    end
  end

  def maybe_send(
        %WebPushSubscription{endpoint: endpoint, p256dh: p256dh, auth: auth} =
          web_push_subscription,
        body
      ) do
    if may_send?(web_push_subscription) do
      subscription = %{
        endpoint: endpoint,
        keys: %{p256dh: p256dh, auth: auth}
      }

      retry with: exponential_backoff() |> randomize |> cap(5_000) |> expiry(10_000) do
        case WebPushEncryption.send_web_push(body, subscription) do
          {:ok, _response} -> :ok
          _ -> :error
        end
      after
        _result ->
          Statix.increment("ret.web_push.hub.sent", 1)
          web_push_subscription |> changeset_for_notification_sent |> Repo.update!()
      else
        _error ->
          Statix.increment("ret.web_push.hub.send_error", 1)
      end
    end
  end

  defp may_send?(%WebPushSubscription{last_notified_at: nil}), do: true

  defp may_send?(%WebPushSubscription{last_notified_at: last_notified_at}) do
    limit_ago = Timex.now() |> Timex.shift(seconds: -@push_rate_limit_seconds)
    last_notified_at |> Timex.before?(limit_ago)
  end

  defp find_by_hub_id_and_subscription(hub_id, %{"endpoint" => endpoint}) do
    Repo.one(
      from sub in WebPushSubscription,
        where: sub.hub_id == ^hub_id,
        where: sub.endpoint == ^endpoint
    )
  end

  def endpoint_has_subscriptions?(endpoint) do
    Repo.exists?(from sub in WebPushSubscription, where: sub.endpoint == ^endpoint)
  end

  def changeset_for_new(%WebPushSubscription{} = subscription, hub, params) do
    subscription
    |> cast(params, [:p256dh, :auth, :endpoint])
    |> put_assoc(:hub, hub)
    |> validate_required([:p256dh, :auth, :endpoint, :hub])
  end

  defp changeset_for_notification_sent(%WebPushSubscription{} = subscription) do
    subscription
    |> cast(%{}, [])
    |> put_change(:last_notified_at, Timex.now() |> DateTime.truncate(:second))
  end
end
