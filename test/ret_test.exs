defmodule RetTest do
  use Ret.DataCase
  import Ecto.Query, only: [from: 2]
  import Ret.TestHelpers

  alias Ret.{
    Account,
    AccountFavorite,
    Api,
    Hub,
    HubBinding,
    HubInvite,
    HubRoleMembership,
    Identity,
    Login,
    OAuthProvider,
    Repo,
    RoomObject,
    WebPushSubscription
  }

  describe "account deletion" do
    test "deletes account, login, identity, oauthproviders, and api_credentials" do
      {:ok, admin_account: admin_account} = create_admin_account("admin")
      test_account = create_account("test")

      Account.set_identity!(test_account, "test identity")

      Repo.insert(%OAuthProvider{
        source: :discord,
        account: test_account,
        provider_account_id: "discord-test-user"
      })

      Api.TokenUtils.gen_token_for_account(test_account)

      %Account{} = Ret.get_account_by_id(test_account.account_id)
      1 = count(Login, test_account)
      1 = count(Identity, test_account)
      1 = count(OAuthProvider, test_account)
      1 = count(Api.Credentials, test_account)

      assert :ok = Ret.delete_account(admin_account, test_account)

      assert nil === Ret.get_account_by_id(test_account.account_id)
      assert 0 === count(Login, test_account)
      assert 0 === count(Identity, test_account)
      assert 0 === count(OAuthProvider, test_account)
      assert 0 === count(Api.Credentials, test_account)
    end

    test "deletes hub and associated entities" do
      {:ok, admin_account: admin_account} = create_admin_account("admin")
      test_account = create_account("test")
      test_hub_member_account = create_account("test_member")

      {:ok, hub} =
        Repo.insert(%Hub{
          name: "test hub",
          slug: "fake test slug",
          created_by_account: test_account
        })

      Repo.insert(%HubBinding{
        hub: hub,
        type: :discord,
        community_id: "fake-community-id",
        channel_id: "fake-channel-id"
      })

      Repo.insert(%AccountFavorite{
        hub: hub,
        account: test_account
      })

      Repo.insert(%HubInvite{
        hub: hub,
        hub_invite_sid: "fake-invite-sid"
      })

      Repo.insert(%HubRoleMembership{
        hub: hub,
        account: test_hub_member_account
      })

      Repo.insert(%RoomObject{
        hub: hub,
        account: test_account,
        object_id: "fake object id",
        gltf_node: "fake gltf node"
      })

      Repo.insert(%WebPushSubscription{
        hub: hub,
        endpoint: "fake-endpoint",
        p256dh: "fake-key",
        auth: "fake-auth-key"
      })

      1 = count_hubs(test_account)
      1 = count(AccountFavorite, hub)
      1 = count(HubBinding, hub)
      1 = count(HubInvite, hub)
      1 = count(HubRoleMembership, hub)
      1 = count(RoomObject, hub)
      1 = count(WebPushSubscription, hub)

      assert :ok = Ret.delete_account(admin_account, test_account)

      assert 0 === count_hubs(test_account)
      assert 0 === count(AccountFavorite, hub)
      assert 0 === count(HubBinding, hub)
      assert 0 === count(HubInvite, hub)
      assert 0 === count(HubRoleMembership, hub)
      assert 0 === count(RoomObject, hub)
      assert 0 === count(WebPushSubscription, hub)
    end

    test "deletes entities associated with an account, even when they belong to a hub owned by another account" do
      {:ok, admin_account: admin_account} = create_admin_account("test_admin")
      hub_owner = create_account("test_owner")
      hub_user = create_account("test_user")

      {:ok, hub} =
        Repo.insert(%Hub{
          name: "test hub",
          slug: "fake test slug",
          created_by_account: hub_owner
        })

      Repo.insert(%AccountFavorite{
        hub: hub,
        account: hub_user
      })

      Repo.insert(%HubRoleMembership{
        hub: hub,
        account: hub_user
      })

      Repo.insert(%RoomObject{
        hub: hub,
        account: hub_user,
        object_id: "fake object id",
        gltf_node: "fake gltf node"
      })

      1 = count_hubs(hub_owner)
      1 = count(AccountFavorite, hub)
      1 = count(HubRoleMembership, hub)
      1 = count(RoomObject, hub)

      assert :ok = Ret.delete_account(admin_account, hub_user)

      assert 1 === count_hubs(hub_owner)
      assert 0 === count(AccountFavorite, hub)
      assert 0 === count(HubRoleMembership, hub)
      assert 0 === count(RoomObject, hub)
    end

    test "deletes entities associated with hub, even when they belong to a hub owned by another account" do
      {:ok, admin_account: admin_account} = create_admin_account("test_admin")
      hub_owner = create_account("test_owner")
      hub_user = create_account("test_user")

      {:ok, hub} =
        Repo.insert(%Hub{
          name: "test hub",
          slug: "fake test slug",
          created_by_account: hub_owner
        })

      Repo.insert(%AccountFavorite{
        hub: hub,
        account: hub_user
      })

      Repo.insert(%HubRoleMembership{
        hub: hub,
        account: hub_user
      })

      Repo.insert(%RoomObject{
        hub: hub,
        account: hub_user,
        object_id: "fake object id",
        gltf_node: "fake gltf node"
      })

      1 = count(AccountFavorite, hub_user)
      1 = count(HubRoleMembership, hub_user)
      1 = count(RoomObject, hub_user)

      assert :ok = Ret.delete_account(admin_account, hub_owner)

      assert 0 === count(AccountFavorite, hub_user)
      assert 0 === count(HubRoleMembership, hub_user)
      assert 0 === count(RoomObject, hub_user)
    end
  end

  defp count_hubs(account) do
    Ret.Repo.aggregate(
      from(h in Hub, where: h.created_by_account_id == ^account.account_id),
      :count
    )
  end

  defp count(queryable, %Account{} = account) do
    Ret.Repo.aggregate(
      from(record in queryable, where: record.account_id == ^account.account_id),
      :count
    )
  end

  defp count(queryable, %Hub{} = hub) do
    Ret.Repo.aggregate(
      from(record in queryable, where: record.hub_id == ^hub.hub_id),
      :count
    )
  end
end
