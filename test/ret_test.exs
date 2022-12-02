defmodule RetTest do
  use Ret.DataCase

  import Ret.Schema, only: [is_schema: 1]

  import Ret.TestHelpers,
    only: [create_admin_account: 1, create_account: 1, generate_temp_owned_file: 1]

  alias Ret.{
    Account,
    AccountFavorite,
    Api,
    Asset,
    Avatar,
    AvatarListing,
    Hub,
    HubBinding,
    HubInvite,
    HubRoleMembership,
    Identity,
    Login,
    OAuthProvider,
    OwnedFile,
    Project,
    ProjectAsset,
    Repo,
    RoomObject,
    Scene,
    SceneListing,
    Sids,
    Storage,
    WebPushSubscription
  }

  describe "delete_account/2" do
    setup do
      {:ok, admin_account: current_user} = create_admin_account("current user")
      %{account_to_delete: create_account("account to delete"), current_user: current_user}
    end

    test "deletes account", %{account_to_delete: account_to_delete, current_user: current_user} do
      %Account{} = repo_reload(account_to_delete)

      assert :ok === Ret.delete_account(account_to_delete.account_id, current_user)
      refute repo_reload(account_to_delete)
    end

    test "deletes account owned files", %{
      account_to_delete: account_to_delete,
      current_user: current_user
    } do
      owned_file = generate_temp_owned_file(account_to_delete)

      %OwnedFile{} = repo_reload(owned_file)
      true = file_on_disk?(owned_file)

      assert :ok === Ret.delete_account(account_to_delete.account_id, current_user)
      refute repo_reload(owned_file)
      refute file_on_disk?(owned_file)
    end

    test "deletes account favorites", %{
      account_to_delete: account_to_delete,
      current_user: current_user
    } do
      own_hub = create_hub(account_to_delete)
      member_hub = create_hub()
      favorite1 = Repo.insert!(%AccountFavorite{account: account_to_delete, hub: own_hub})
      favorite2 = Repo.insert!(%AccountFavorite{account: account_to_delete, hub: member_hub})

      assert :ok === Ret.delete_account(account_to_delete.account_id, current_user)
      refute repo_reload(favorite1)
      refute repo_reload(favorite2)
    end

    test "deletes API credentials", %{
      account_to_delete: account_to_delete,
      current_user: current_user
    } do
      Api.TokenUtils.gen_token_for_account(account_to_delete)
      credentials = Repo.get_by(Api.Credentials, account_id: account_to_delete.account_id)

      assert :ok === Ret.delete_account(account_to_delete.account_id, current_user)
      refute repo_reload(credentials)
    end

    test "deletes assets", %{account_to_delete: account_to_delete, current_user: current_user} do
      asset = create_asset(account_to_delete)

      %Asset{} = repo_reload(asset)

      assert :ok === Ret.delete_account(account_to_delete.account_id, current_user)
      refute repo_reload(asset)
    end

    test "deletes asset owned files", %{
      account_to_delete: account_to_delete,
      current_user: current_user
    } do
      asset = create_asset(account_to_delete)
      owned_files = owned_files(asset, [:asset_owned_file, :thumbnail_owned_file])

      for owned_file <- owned_files do
        %OwnedFile{} = repo_reload(owned_file)
        true = file_on_disk?(owned_file)
      end

      assert :ok === Ret.delete_account(account_to_delete.account_id, current_user)

      for owned_file <- owned_files do
        refute repo_reload(owned_file)
        refute file_on_disk?(owned_file)
      end
    end

    test "deletes avatars", %{account_to_delete: account_to_delete, current_user: current_user} do
      avatar = create_avatar(account_to_delete)

      %Avatar{} = repo_reload(avatar)

      assert :ok === Ret.delete_account(account_to_delete.account_id, current_user)
      refute repo_reload(avatar)
    end

    test "deletes avatar owned files", %{
      account_to_delete: account_to_delete,
      current_user: current_user
    } do
      avatar = create_avatar(account_to_delete)
      owned_files = avatar_owned_files(avatar)

      for owned_file <- owned_files do
        %OwnedFile{} = repo_reload(owned_file)
        true = file_on_disk?(owned_file)
      end

      assert :ok === Ret.delete_account(account_to_delete.account_id, current_user)

      for owned_file <- owned_files do
        refute repo_reload(owned_file)
        refute file_on_disk?(owned_file)
      end
    end

    test "reassigns parent avatars to current user", %{
      account_to_delete: account_to_delete,
      current_user: current_user
    } do
      account_to_delete_id = account_to_delete.account_id
      avatar = create_avatar(account_to_delete)
      create_child_avatar(avatar)

      %Avatar{account_id: ^account_to_delete_id} = repo_reload(avatar)

      assert :ok === Ret.delete_account(account_to_delete.account_id, current_user)
      assert avatar = repo_reload(avatar)
      assert current_user.account_id === avatar.account_id
    end

    test "reassigns owned files of parent avatar to current user", %{
      account_to_delete: account_to_delete,
      current_user: current_user
    } do
      account_to_delete_id = account_to_delete.account_id
      avatar = create_avatar(account_to_delete)
      owned_files = avatar_owned_files(avatar)
      create_child_avatar(avatar)

      for owned_file <- owned_files do
        ^account_to_delete_id = reload_account_id(owned_file)
        true = file_on_disk?(owned_file)
      end

      assert :ok === Ret.delete_account(account_to_delete.account_id, current_user)

      for owned_file <- owned_files do
        assert current_user.account_id === reload_account_id(owned_file)
        assert file_on_disk?(owned_file)
      end
    end

    test "reassigns listed avatars to current user", %{
      account_to_delete: account_to_delete,
      current_user: current_user
    } do
      account_to_delete_id = account_to_delete.account_id
      avatar = create_avatar(account_to_delete)
      create_avatar_listing(avatar)

      %Avatar{account_id: ^account_to_delete_id} = repo_reload(avatar)

      assert :ok === Ret.delete_account(account_to_delete.account_id, current_user)
      assert avatar = repo_reload(avatar)
      assert current_user.account_id === avatar.account_id
    end

    test "reassigns owned files of listed avatar to current user", %{
      account_to_delete: account_to_delete,
      current_user: current_user
    } do
      account_to_delete_id = account_to_delete.account_id
      avatar = create_avatar(account_to_delete)
      owned_files = avatar_owned_files(avatar)
      create_avatar_listing(avatar)

      for owned_file <- owned_files do
        ^account_to_delete_id = reload_account_id(owned_file)
        true = file_on_disk?(owned_file)
      end

      assert :ok === Ret.delete_account(account_to_delete.account_id, current_user)

      for owned_file <- owned_files do
        assert current_user.account_id === reload_account_id(owned_file)
        assert file_on_disk?(owned_file)
      end
    end

    test "deletes hubs", %{account_to_delete: account_to_delete, current_user: current_user} do
      hub = create_hub(account_to_delete)

      %Hub{} = repo_reload(hub)

      assert :ok === Ret.delete_account(account_to_delete.account_id, current_user)
      refute repo_reload(hub)
    end

    test "deletes hub account favorites", %{
      account_to_delete: account_to_delete,
      current_user: current_user
    } do
      hub = create_hub(account_to_delete)
      other_account = create_account("other account")
      favorite = Repo.insert!(%AccountFavorite{account: other_account, hub: hub})

      assert :ok === Ret.delete_account(account_to_delete.account_id, current_user)
      refute repo_reload(favorite)
    end

    test "deletes hub bindings", %{
      account_to_delete: account_to_delete,
      current_user: current_user
    } do
      hub = create_hub(account_to_delete)

      binding =
        Repo.insert!(%HubBinding{
          channel_id: "fake channel id",
          community_id: "fake community id",
          hub: hub,
          type: :discord
        })

      assert :ok === Ret.delete_account(account_to_delete.account_id, current_user)
      refute repo_reload(binding)
    end

    test "deletes hub invites", %{
      account_to_delete: account_to_delete,
      current_user: current_user
    } do
      hub = create_hub(account_to_delete)
      invite = Repo.insert!(%HubInvite{hub: hub, hub_invite_sid: "dummy sid"})

      assert :ok === Ret.delete_account(account_to_delete.account_id, current_user)
      refute repo_reload(invite)
    end

    test "deletes hub hub-role memberships", %{
      account_to_delete: account_to_delete,
      current_user: current_user
    } do
      hub = create_hub(account_to_delete)
      other_account = create_account("other account")
      membership = Repo.insert!(%HubRoleMembership{account: other_account, hub: hub})

      assert :ok === Ret.delete_account(account_to_delete.account_id, current_user)
      refute repo_reload(membership)
    end

    test "deletes hub room objects", %{
      account_to_delete: account_to_delete,
      current_user: current_user
    } do
      hub = create_hub(account_to_delete)
      other_account = create_account("other account")
      object = create_room_object(hub, other_account)

      %RoomObject{} = repo_reload(object)

      assert :ok === Ret.delete_account(account_to_delete.account_id, current_user)
      refute repo_reload(object)
    end

    test "deletes hub web push subscriptions", %{
      account_to_delete: account_to_delete,
      current_user: current_user
    } do
      hub = create_hub(account_to_delete)

      subscription =
        Repo.insert!(%WebPushSubscription{
          auth: "fake auth",
          endpoint: "fake endpoint",
          hub: hub,
          p256dh: "fake key"
        })

      assert :ok === Ret.delete_account(account_to_delete.account_id, current_user)
      refute repo_reload(subscription)
    end

    test "deletes hub-role memberships", %{
      account_to_delete: account_to_delete,
      current_user: current_user
    } do
      own_hub = create_hub(account_to_delete)
      member_hub = create_hub()
      membership1 = Repo.insert!(%HubRoleMembership{account: account_to_delete, hub: own_hub})
      membership2 = Repo.insert!(%HubRoleMembership{account: account_to_delete, hub: member_hub})

      assert :ok === Ret.delete_account(account_to_delete.account_id, current_user)
      refute repo_reload(membership1)
      refute repo_reload(membership2)
    end

    test "deletes identity", %{account_to_delete: account_to_delete, current_user: current_user} do
      %{identity: identity} = Account.set_identity!(account_to_delete, "test identity")

      %Identity{} = repo_reload(identity)

      assert :ok === Ret.delete_account(account_to_delete.account_id, current_user)
      refute repo_reload(identity)
    end

    test "deletes login", %{account_to_delete: account_to_delete, current_user: current_user} do
      login = Repo.get_by(Login, account_id: account_to_delete.account_id)

      assert :ok === Ret.delete_account(account_to_delete.account_id, current_user)
      refute repo_reload(login)
    end

    test "deletes OAuth providers", %{
      account_to_delete: account_to_delete,
      current_user: current_user
    } do
      provider =
        Repo.insert!(%OAuthProvider{
          account: account_to_delete,
          provider_account_id: "fake id",
          source: :discord
        })

      assert :ok === Ret.delete_account(account_to_delete.account_id, current_user)
      refute repo_reload(provider)
    end

    test "deletes projects", %{account_to_delete: account_to_delete, current_user: current_user} do
      project = create_project(account_to_delete)

      %Project{} = repo_reload(project)

      assert :ok === Ret.delete_account(account_to_delete.account_id, current_user)
      refute repo_reload(project)
    end

    test "deletes project owned files", %{
      account_to_delete: account_to_delete,
      current_user: current_user
    } do
      project = create_project(account_to_delete)
      owned_files = owned_files(project, [:project_owned_file, :thumbnail_owned_file])

      for owned_file <- owned_files do
        %OwnedFile{} = repo_reload(owned_file)
        true = file_on_disk?(owned_file)
      end

      assert :ok === Ret.delete_account(account_to_delete.account_id, current_user)

      for owned_file <- owned_files do
        refute repo_reload(owned_file)
        refute file_on_disk?(owned_file)
      end
    end

    test "deletes project assets", %{
      account_to_delete: account_to_delete,
      current_user: current_user
    } do
      %{project_id: project_id} = create_project(account_to_delete)
      %{asset_id: asset_id} = create_asset(account_to_delete)
      project_asset = Repo.insert!(%ProjectAsset{asset_id: asset_id, project_id: project_id})

      assert :ok === Ret.delete_account(account_to_delete.account_id, current_user)
      refute repo_reload(project_asset)
    end

    test "deletes room objects", %{
      account_to_delete: account_to_delete,
      current_user: current_user
    } do
      own_hub = create_hub(account_to_delete)
      member_hub = create_hub()
      object1 = create_room_object(own_hub, account_to_delete)
      object2 = create_room_object(member_hub, account_to_delete)

      %RoomObject{} = repo_reload(object1)
      %RoomObject{} = repo_reload(object2)

      assert :ok === Ret.delete_account(account_to_delete.account_id, current_user)
      refute repo_reload(object1)
      refute repo_reload(object2)
    end

    test "deletes scenes", %{account_to_delete: account_to_delete, current_user: current_user} do
      scene = create_scene(account_to_delete)

      %Scene{} = repo_reload(scene)

      assert :ok === Ret.delete_account(account_to_delete.account_id, current_user)
      refute repo_reload(scene)
    end

    test "deletes scene owned files", %{
      account_to_delete: account_to_delete,
      current_user: current_user
    } do
      scene = create_scene(account_to_delete)
      owned_files = scene_owned_files(scene)

      for owned_file <- owned_files do
        %OwnedFile{} = repo_reload(owned_file)
        true = file_on_disk?(owned_file)
      end

      assert :ok === Ret.delete_account(account_to_delete.account_id, current_user)

      for owned_file <- owned_files do
        refute repo_reload(owned_file)
        refute file_on_disk?(owned_file)
      end
    end

    test "rassigns parent scenes to current user", %{
      account_to_delete: account_to_delete,
      current_user: current_user
    } do
      account_to_delete_id = account_to_delete.account_id
      scene = create_scene(account_to_delete)
      create_child_scene(scene)

      %Scene{account_id: ^account_to_delete_id} = repo_reload(scene)

      assert :ok === Ret.delete_account(account_to_delete.account_id, current_user)
      assert scene = repo_reload(scene)
      assert current_user.account_id === scene.account_id
    end

    test "reassigns owned files of parent scene to current user", %{
      account_to_delete: account_to_delete,
      current_user: current_user
    } do
      account_to_delete_id = account_to_delete.account_id
      scene = create_scene(account_to_delete)
      owned_files = scene_owned_files(scene)
      create_child_scene(scene)

      for owned_file <- owned_files do
        ^account_to_delete_id = reload_account_id(owned_file)
        true = file_on_disk?(owned_file)
      end

      assert :ok === Ret.delete_account(account_to_delete.account_id, current_user)

      for owned_file <- owned_files do
        assert current_user.account_id === reload_account_id(owned_file)
        assert file_on_disk?(owned_file)
      end
    end

    test "reassigns listed scenes to current user", %{
      account_to_delete: account_to_delete,
      current_user: current_user
    } do
      account_to_delete_id = account_to_delete.account_id
      scene = create_scene(account_to_delete)
      create_scene_listing(scene)

      %Scene{account_id: ^account_to_delete_id} = repo_reload(scene)

      assert :ok === Ret.delete_account(account_to_delete.account_id, current_user)
      assert scene = repo_reload(scene)
      assert current_user.account_id === scene.account_id
    end

    test "reassigns owned files of listed scene to current user", %{
      account_to_delete: account_to_delete,
      current_user: current_user
    } do
      account_to_delete_id = account_to_delete.account_id
      scene = create_scene(account_to_delete)
      owned_files = scene_owned_files(scene)
      create_scene_listing(scene)

      for owned_file <- owned_files do
        ^account_to_delete_id = reload_account_id(owned_file)
        true = file_on_disk?(owned_file)
      end

      assert :ok === Ret.delete_account(account_to_delete.account_id, current_user)

      for owned_file <- owned_files do
        assert current_user.account_id === reload_account_id(owned_file)
        assert file_on_disk?(owned_file)
      end
    end

    test "with a non-admin user", %{account_to_delete: account_to_delete} do
      current_user = create_account("non-admin")

      assert {:error, :forbidden} ===
               Ret.delete_account(account_to_delete.account_id, current_user)

      assert repo_reload(account_to_delete)
    end

    test "with an admin account to delete", %{current_user: current_user} do
      {:ok, admin_account: account_to_delete} = create_admin_account("admin account")

      assert {:error, :forbidden} ===
               Ret.delete_account(account_to_delete.account_id, current_user)

      assert repo_reload(account_to_delete)
    end

    test "with the user’s own account to delete" do
      {:ok, admin_account: account} = create_admin_account("own account")

      assert {:error, :forbidden} === Ret.delete_account(account.account_id, account)
      assert repo_reload(account)
    end
  end

  defp avatar_owned_files(%Avatar{} = avatar) do
    owned_files(avatar, [
      :base_map_owned_file,
      :bin_owned_file,
      :emissive_map_owned_file,
      :gltf_owned_file,
      :normal_map_owned_file,
      :orm_map_owned_file,
      :thumbnail_owned_file
    ])
  end

  @spec create_asset(Account.t()) :: Asset.t()
  defp create_asset(%Account{} = account) do
    [asset_owned_file, thumbnail_owned_file] =
      account
      |> temp_owned_files()
      |> Enum.take(2)

    Repo.insert!(%Asset{
      account_id: account.account_id,
      asset_owned_file: asset_owned_file,
      asset_sid: "fake-asset-sid-#{Sids.generate_sid()}",
      name: "fake asset",
      thumbnail_owned_file: thumbnail_owned_file,
      type: :image
    })
  end

  @spec create_avatar(Account.t()) :: Avatar.t()
  defp create_avatar(%Account{} = account) do
    [
      gltf_owned_file,
      bin_owned_file,
      thumbnail_owned_file,
      base_map_owned_file,
      emissive_map_owned_file,
      normal_map_owned_file,
      orm_map_owned_file
    ] =
      account
      |> temp_owned_files()
      |> Enum.take(7)

    Repo.insert!(%Avatar{
      account_id: account.account_id,
      avatar_sid: Integer.to_string(account.account_id),
      base_map_owned_file: base_map_owned_file,
      bin_owned_file: bin_owned_file,
      emissive_map_owned_file: emissive_map_owned_file,
      gltf_owned_file: gltf_owned_file,
      name: "fake avatar",
      normal_map_owned_file: normal_map_owned_file,
      orm_map_owned_file: orm_map_owned_file,
      slug: "fake-avatar-slug",
      thumbnail_owned_file: thumbnail_owned_file
    })
  end

  @spec create_avatar_listing(Avatar.t()) :: AvatarListing.t()
  defp create_avatar_listing(%Avatar{} = avatar),
    do:
      Repo.insert!(%AvatarListing{
        avatar_id: avatar.avatar_id,
        avatar_listing_sid: "fake-avatar-listing-sid",
        base_map_owned_file: avatar.base_map_owned_file,
        bin_owned_file: avatar.bin_owned_file,
        emissive_map_owned_file: avatar.emissive_map_owned_file,
        gltf_owned_file: avatar.gltf_owned_file,
        name: "fake avatar listing",
        normal_map_owned_file: avatar.normal_map_owned_file,
        orm_map_owned_file: avatar.orm_map_owned_file,
        slug: "fake-avatar-listing-slug",
        thumbnail_owned_file: avatar.thumbnail_owned_file
      })

  @spec create_child_avatar(Avatar.t()) :: Avatar.t()
  defp create_child_avatar(%Avatar{} = avatar) do
    account = create_account("other account")

    Repo.insert!(%Avatar{
      account_id: account.account_id,
      avatar_sid: "fake-child-avatar-sid",
      name: "fake child avatar",
      parent_avatar_id: avatar.avatar_id,
      slug: "fake-child-avatar-slug"
    })
  end

  @spec create_child_scene(Scene.t()) :: Scene.t()
  defp create_child_scene(%Scene{} = scene) do
    account = create_account("other account")

    [screenshot_owned_file, model_owned_file] =
      account
      |> temp_owned_files()
      |> Enum.take(2)

    Repo.insert!(%Scene{
      account_id: account.account_id,
      scene_sid: "fake-child-scene-sid",
      model_owned_file_id: model_owned_file.owned_file_id,
      name: "fake child scene",
      parent_scene_id: scene.scene_id,
      screenshot_owned_file_id: screenshot_owned_file.owned_file_id,
      slug: "fake-child-scene-slug"
    })
  end

  @spec create_hub :: Hub.t()
  defp create_hub,
    do:
      "hub owner"
      |> create_account()
      |> create_hub()

  @spec create_hub(Account.t()) :: Hub.t()
  defp create_hub(%Account{} = account),
    do:
      Repo.insert!(%Hub{
        created_by_account: account,
        name: "test hub",
        scene: create_scene(account),
        slug: "dummy-slug"
      })

  @spec create_project(Account.t()) :: Project.t()
  defp create_project(%Account{} = account) do
    [project_owned_file, thumbnail_owned_file] =
      account
      |> temp_owned_files()
      |> Enum.take(2)

    Repo.insert!(%Project{
      created_by_account_id: account.account_id,
      name: "fake project",
      project_owned_file: project_owned_file,
      thumbnail_owned_file: thumbnail_owned_file
    })
  end

  @spec create_room_object(Hub.t(), Account.t()) :: RoomObject.t()
  defp create_room_object(%Hub{} = hub, %Account{} = account),
    do:
      Repo.insert!(%RoomObject{
        account: account,
        gltf_node: "fake node",
        hub: hub,
        object_id: "fake id"
      })

  @spec create_scene(Account.t()) :: Scene.t()
  defp create_scene(%Account{} = account) do
    [scene_owned_file, screenshot_owned_file, model_owned_file] =
      account
      |> temp_owned_files()
      |> Enum.take(3)

    {:ok, scene} =
      Repo.insert(%Scene{
        account_id: account.account_id,
        model_owned_file: model_owned_file,
        name: "fake scene",
        scene_owned_file: scene_owned_file,
        screenshot_owned_file: screenshot_owned_file,
        slug: "fake-scene-slug"
      })

    account
    |> create_project()
    |> Ecto.Changeset.change(scene_id: scene.scene_id)
    |> Repo.update!()

    scene
  end

  @spec create_scene_listing(Scene.t()) :: SceneListing.t()
  defp create_scene_listing(%Scene{} = scene),
    do:
      Repo.insert!(%SceneListing{
        model_owned_file: scene.model_owned_file,
        name: "fake scene listing",
        scene_id: scene.scene_id,
        scene_owned_file: scene.scene_owned_file,
        screenshot_owned_file: scene.screenshot_owned_file,
        slug: "fake-scene-listing-slug"
      })

  @spec file_on_disk?(OwnedFile.t()) :: boolean
  defp file_on_disk?(%OwnedFile{} = owned_file) do
    [_base_path, meta_file_path, blob_file_path] = Storage.paths_for_owned_file(owned_file)
    File.exists?(meta_file_path) and File.exists?(blob_file_path)
  end

  @spec owned_files(Ecto.Schema.schema(), [atom]) :: [OwnedFile.t()]
  defp owned_files(schema, assocs) when is_schema(schema) and is_list(assocs) do
    for assoc <- assocs do
      Map.fetch!(schema, assoc)
    end
  end

  # TODO: Replace calls with Repo.reload/1 after Ecto updgrade
  @spec repo_reload(schema) :: schema when schema: Ecto.Schema.schema()
  defp repo_reload(schema) when is_schema(schema) do
    [primary_key] = schema.__struct__.__schema__(:primary_key)
    Repo.get(schema.__struct__, Map.fetch!(schema, primary_key))
  end

  @spec reload_account_id(Ecto.Schema.schema()) :: Account.id()
  defp reload_account_id(schema) when is_schema(schema),
    do:
      schema
      |> repo_reload()
      |> Map.fetch!(:account_id)

  @spec scene_owned_files(Scene.t()) :: [OwnedFile.t()]
  defp scene_owned_files(%Scene{} = scene),
    do: owned_files(scene, [:model_owned_file, :screenshot_owned_file, :scene_owned_file])

  @spec temp_owned_files(Account.t()) :: Enumerable.t(OwnedFile.t())
  defp temp_owned_files(%Account{} = account),
    do: Stream.repeatedly(fn -> generate_temp_owned_file(account) end)
end
