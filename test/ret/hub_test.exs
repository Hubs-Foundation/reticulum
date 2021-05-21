defmodule Ret.HubTest do
  use Ret.DataCase
  import Ret.TestHelpers

  alias Ret.{Hub, HubRoleMembership, Repo}

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
    hub = hub |> Repo.preload([:hub_bindings, :hub_role_memberships])

    %{join_hub: true, update_hub: false, close_hub: false, mute_users: false, amplify_audio: false} =
      hub |> Hub.perms_for_account(Ret.Account.account_for_email("non-creator@mozilla.com"))
  end

  test "should deny permissions for anon", %{scene: scene} do
    {:ok, hub} = %Hub{} |> Hub.changeset(scene, %{name: "Test Hub"}) |> Repo.insert()
    hub = hub |> Repo.preload([:hub_bindings])

    %{join_hub: true, update_hub: false, close_hub: false, mute_users: false, amplify_audio: false} =
      hub |> Hub.perms_for_account(nil)
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

    hub = hub |> Repo.preload([:hub_bindings, :hub_role_memberships])

    %{join_hub: true, update_hub: true, close_hub: true, mute_users: true, amplify_audio: true} =
      hub |> Hub.perms_for_account(account)
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

  test "hub permissions map can be converted to bit field integer" do
    member_permissions = %{spawn_and_move_media: true}
    bit_field = member_permissions |> Hub.member_permissions_to_int()
    assert bit_field == 1
  end

  test "invalid hub permissions map cannot be converted to bit field integer" do
    member_permissions = %{fake_permission: false}
    assert_raise ArgumentError, fn -> member_permissions |> Hub.member_permissions_to_int() end
  end

  test "hub permissions bit field integer can be queried for a permission" do
    bit_field = 1
    assert Hub.has_member_permission?(%Hub{member_permissions: bit_field}, :spawn_and_move_media)
  end

  test "hub permissions bit field integer cannot be queried with an invalid permission" do
    bit_field = 1

    assert_raise ArgumentError, fn ->
      Hub.has_member_permission?(%Hub{member_permissions: bit_field}, :fake_permission)
    end
  end

  test "hubs can assign new owners", %{
    account: account,
    account2: account2,
    scene: scene
  } do
    {:ok, hub} =
      %Hub{}
      |> Hub.changeset(scene, %{name: "Test Hub"})
      |> Hub.add_account_to_changeset(account)
      |> Repo.insert()

    hub = hub |> Repo.preload([:hub_role_memberships])

    assert hub |> Hub.is_owner?(account.account_id) === true
    assert hub |> Hub.is_owner?(account2.account_id) === false

    hub = hub |> Hub.add_owner!(account2)

    assert hub |> Hub.is_owner?(account.account_id) === true
    assert hub |> Hub.is_owner?(account2.account_id) === true

    hub = hub |> Hub.remove_owner!(account2)

    assert hub |> Hub.is_owner?(account.account_id) === true
    assert hub |> Hub.is_owner?(account2.account_id) === false
  end

  test "adding creator as owner has no side effects", %{
    account: account,
    scene: scene
  } do
    {:ok, hub} =
      %Hub{}
      |> Hub.changeset(scene, %{name: "Test Hub"})
      |> Hub.add_account_to_changeset(account)
      |> Repo.insert()

    hub = hub |> Hub.add_owner!(account)
    assert HubRoleMembership |> where(hub_id: ^hub.hub_id) |> Repo.aggregate(:count, :hub_role_membership_id) === 0
  end

  test "double adding the same account doesn't fail", %{
    account: account,
    account2: account2,
    scene: scene
  } do
    {:ok, hub} =
      %Hub{}
      |> Hub.changeset(scene, %{name: "Test Hub"})
      |> Hub.add_account_to_changeset(account)
      |> Repo.insert()

    hub = hub |> Hub.add_owner!(account2)
    hub = hub |> Hub.add_owner!(account2)
    hub = hub |> Hub.add_owner!(account2)

    assert HubRoleMembership |> where(hub_id: ^hub.hub_id) |> Repo.aggregate(:count, :hub_role_membership_id) === 1
  end
end
