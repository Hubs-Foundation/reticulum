defmodule Ret.SupportSubscriptionTest do
  use Ret.DataCase

  alias Ret.{Support, SupportSubscription}

  test "support availability" do
    assert Support.available?() == false

    %SupportSubscription{}
    |> SupportSubscription.changeset(%{identifier: "csr"})
    |> Ret.Repo.insert!()

    assert Support.available?() == true
  end
end
