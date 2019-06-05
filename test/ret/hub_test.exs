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

  test "should have creator assignment token if no account assigned", %{scene: scene} do
    {:ok, hub} = %Hub{} |> Hub.changeset(scene, %{name: "Test Hub"}) |> Repo.insert()

    assert hub.creator_assignment_token != nil
  end

  test "should have embed token", %{scene: scene} do
    {:ok, hub} = %Hub{} |> Hub.changeset(scene, %{name: "Test Hub"}) |> Repo.insert()

    assert hub.embed_token != nil
  end

  test "should allow creator assignment if token is correct", %{scene: scene, account: account} do
    {:ok, hub} = %Hub{} |> Hub.changeset(scene, %{name: "Test Hub"}) |> Repo.insert()

    hub =
      hub
      |> Repo.preload(created_by_account: [])
      |> Hub.changeset_for_creator_assignment(account, hub.creator_assignment_token)
      |> Repo.update!()

    assert hub.created_by_account_id == account.account_id
  end

  test "show disallow creator assignment if token is incorrect", %{scene: scene, account: account} do
    {:ok, hub} = %Hub{} |> Hub.changeset(scene, %{name: "Test Hub"}) |> Repo.insert()

    hub =
      hub
      |> Repo.preload(created_by_account: [])
      |> Hub.changeset_for_creator_assignment(account, "bad token")
      |> Repo.update!()

    assert hub.created_by_account_id == nil
  end

  test "show disallow creator assignment if token is already used", %{
    scene: scene,
    account: account,
    account2: account2
  } do
    {:ok, hub} = %Hub{} |> Hub.changeset(scene, %{name: "Test Hub"}) |> Repo.insert()

    hub =
      hub
      |> Repo.preload(created_by_account: [])
      |> Hub.changeset_for_creator_assignment(account, hub.creator_assignment_token)
      |> Repo.update!()

    hub =
      hub
      |> Repo.preload(created_by_account: [])
      |> Hub.changeset_for_creator_assignment(account2, hub.creator_assignment_token)
      |> Repo.update!()

    hub =
      hub
      |> Repo.preload(created_by_account: [])
      |> Hub.changeset_for_creator_assignment(account2, nil)
      |> Repo.update!()

    assert hub.created_by_account_id == account.account_id
  end

  test "should not have creator assignment token if account assigned", %{account: account, scene: scene} do
    {:ok, hub} =
      %Hub{}
      |> Hub.changeset(scene, %{name: "Test Hub"})
      |> Hub.add_account_to_changeset(account)
      |> Repo.insert()

    assert hub.creator_assignment_token == nil
  end
end
