defmodule Ret.SupportSubscriptionTest do
  use Ret.DataCase

  alias Ret.{SupportSubscription}

  test "support availability" do
    assert SupportSubscription.support_available?() == false

    %SupportSubscription{} |> SupportSubscription.changeset(%{identifier: "csr"}) |> Ret.Repo.insert!()

    assert SupportSubscription.support_available?() == true
  end
end
