defmodule Ret.HubTest do
  use Ret.DataCase
  import Ret.TestHelpers

  alias Ret.{Hub, Repo}

  setup [:create_account, :create_owned_file, :create_scene]

  test "new hub should have entry code", %{scene: scene} do
    {:ok, hub} = %Hub{} |> Hub.changeset(scene, %{name: "Test Hub"}) |> Repo.insert()

    assert hub.entry_code > 0
    assert hub |> Hub.entry_code_expired?() == false
  end
end
