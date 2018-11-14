defmodule Ret.HubTest do
  use Ret.DataCase
  use Bitwise
  import Ret.TestHelpers

  alias Ret.{Hub, Repo}

  setup [:create_account, :create_owned_file, :create_scene]

  test "new hub should have entry code", %{scene: scene} do
    {:ok, hub} = %Hub{} |> Hub.changeset(scene, %{name: "Test Hub"}) |> Repo.insert()

    assert hub.entry_code > 0
    assert hub |> Hub.entry_code_expired?() == false
  end

  test "should generate a new entry code when code is expired/empty", %{scene: scene} do
    {:ok, hub} = %Hub{} |> Hub.changeset(scene, %{name: "Test Hub"}) |> Repo.insert()
    hub = hub |> Ecto.Changeset.change(entry_code: nil) |> Repo.update!()

    assert hub |> Hub.entry_code_expired?() == true

    hub = hub |> Hub.ensure_valid_entry_code!()
    assert hub.entry_code > 0
    assert hub |> Hub.entry_code_expired?() == false
  end

  test "should handle bitmask properly for high order bit", %{scene: scene} do
    {:ok, hub} = %Hub{} |> Hub.changeset(scene, %{name: "Test Hub"}) |> Repo.insert()
    {:ok, hub} = hub |> Hub.changeset_for_new_spawned_object_type(31) |> Repo.update()
    {:ok, hub} = hub |> Hub.changeset_for_new_spawned_object_type(4) |> Repo.update()

    <<expected_value::integer-signed-32>> = <<1 <<< 31 ||| 1 <<< 4::integer-unsigned-32>>
    assert hub.spawned_object_types == expected_value
  end
end
