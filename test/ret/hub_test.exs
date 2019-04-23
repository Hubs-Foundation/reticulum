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

  test "should generate a new entry code when code is expired/empty", %{scene: scene} do
    {:ok, hub} = %Hub{} |> Hub.changeset(scene, %{name: "Test Hub"}) |> Repo.insert()
    hub = hub |> Ecto.Changeset.change(entry_code: nil) |> Repo.update!()

    assert hub |> Hub.entry_code_expired?() == true

    hub = hub |> Hub.ensure_valid_entry_code!()
    assert hub.entry_code > 0
    assert hub |> Hub.entry_code_expired?() == false
  end

  test "should deny permissions for non-creator", %{scene: scene} do
    {:ok, hub} = %Hub{} |> Hub.changeset(scene, %{name: "Test Hub"}) |> Repo.insert()
    hub = hub |> Repo.preload([:hub_bindings])

    %{join_hub: true, update_hub: false, close_hub: false, mute_users: false} =
      hub |> Hub.perms_for_account(Ret.Account.account_for_email("non-creator@mozilla.com"))
  end

  test "should deny permissions for anon", %{scene: scene} do
    {:ok, hub} = %Hub{} |> Hub.changeset(scene, %{name: "Test Hub"}) |> Repo.insert()
    hub = hub |> Repo.preload([:hub_bindings])

    %{join_hub: true, update_hub: false, close_hub: false, mute_users: false} = hub |> Hub.perms_for_account(nil)
  end

  test "should deny entry for closed hub, allow entry for re-opened hub", %{scene: scene} do
    {:ok, hub} = %Hub{} |> Hub.changeset(scene, %{name: "Test Hub"}) |> Repo.insert()
    hub = hub |> Repo.preload([:hub_bindings])

    %{join_hub: true} = hub |> Hub.perms_for_account(nil)

    hub = hub |> Hub.changeset_for_entry_mode(:deny) |> Repo.update!()

    %{join_hub: false} = hub |> Hub.perms_for_account(nil)

    hub = hub |> Hub.changeset_for_entry_mode(:allow) |> Repo.update!()

    %{join_hub: true} = hub |> Hub.perms_for_account(nil)
  end

  test "should grant permssions for hub creator", %{account: account, scene: scene} do
    {:ok, hub} =
      %Hub{}
      |> Hub.changeset(scene, %{name: "Test Hub"})
      |> Hub.add_account_to_changeset(account)
      |> Repo.insert()

    hub = hub |> Repo.preload([:hub_bindings])

    %{join_hub: true, update_hub: true, close_hub: true, mute_users: true} = hub |> Hub.perms_for_account(account)
  end
end
