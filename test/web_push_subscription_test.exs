defmodule Ret.WebPushSubscriptionTest do
  use Ret.DataCase
  import Ret.TestHelpers

  alias Ret.{Hub, WebPushSubscription}

  @stub_subscription %{
    "endpoint" => "endpoint",
    "keys" => %{"p256dh" => "p256dh", "auth" => "auth"}
  }

  setup [:create_account, :create_owned_file, :create_scene, :create_hub]

  alias Ret.{WebPushSubscription}

  test "create new subscription", %{hub: %Hub{hub_id: hub_id} = hub} do
    subscription = WebPushSubscription.subscribe_to_hub(hub, @stub_subscription)

    assert subscription.web_push_subscription_id != nil

    %WebPushSubscription{endpoint: "endpoint", p256dh: "p256dh", auth: "auth", hub_id: ^hub_id} =
      subscription
  end

  test "re-use existing subscription", %{hub: hub} do
    subscription = WebPushSubscription.subscribe_to_hub(hub, @stub_subscription)
    subscription_other = WebPushSubscription.subscribe_to_hub(hub, @stub_subscription)

    assert subscription.web_push_subscription_id == subscription_other.web_push_subscription_id
  end

  test "create a new subscription if endpoint is varied", %{hub: hub} do
    subscription = WebPushSubscription.subscribe_to_hub(hub, @stub_subscription)

    subscription_other =
      WebPushSubscription.subscribe_to_hub(
        hub,
        @stub_subscription |> Map.put("endpoint", "endpoint2")
      )

    assert subscription.web_push_subscription_id != subscription_other.web_push_subscription_id

    %WebPushSubscription{endpoint: "endpoint"} = subscription
    %WebPushSubscription{endpoint: "endpoint2"} = subscription_other
  end

  test "create a new subscription if hub is varied", %{
    scene: scene,
    hub: %Hub{hub_id: hub_id} = hub
  } do
    {:ok, hub: hub_other} = create_hub(%{scene: scene})
    %Hub{hub_id: other_hub_id} = hub_other

    subscription = WebPushSubscription.subscribe_to_hub(hub, @stub_subscription)

    subscription_other = WebPushSubscription.subscribe_to_hub(hub_other, @stub_subscription)

    assert subscription.web_push_subscription_id != subscription_other.web_push_subscription_id

    %WebPushSubscription{hub_id: ^hub_id} = subscription
    %WebPushSubscription{hub_id: ^other_hub_id} = subscription_other
  end

  test "properly checks for has subscriptions", %{scene: scene, hub: %Hub{} = hub} do
    {:ok, hub: hub_other} = create_hub(%{scene: scene})
    assert !WebPushSubscription.endpoint_has_subscriptions?(@stub_subscription["endpoint"])

    WebPushSubscription.subscribe_to_hub(hub, @stub_subscription)
    assert WebPushSubscription.endpoint_has_subscriptions?(@stub_subscription["endpoint"])

    WebPushSubscription.subscribe_to_hub(hub_other, @stub_subscription)
    assert WebPushSubscription.endpoint_has_subscriptions?(@stub_subscription["endpoint"])
  end

  test "remove a subscription", %{hub: %Hub{hub_id: hub_id} = hub} do
    WebPushSubscription.subscribe_to_hub(hub, @stub_subscription)
    WebPushSubscription.unsubscribe_from_hub(hub, @stub_subscription)

    existing =
      Repo.one(
        from sub in WebPushSubscription,
          where: sub.endpoint == "endpoint",
          where: sub.hub_id == ^hub_id
      )

    assert existing == nil
  end
end
