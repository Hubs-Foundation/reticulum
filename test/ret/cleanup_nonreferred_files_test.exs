defmodule Ret.CleanupNonreferredFilesTest do
  use Ret.DataCase
  import Ret.TestHelpers

  alias Ret.{
    AppConfig,
    Avatar,
    AvatarListing,
    DummyData,
    NonReferredOwnedFile,
    OwnedFile,
    Repo,
    RoomObject,
    Scene,
    Storage
  }

  setup do
    on_exit(fn ->
      clear_all_stored_files()
    end)
  end

  # Make an account and two owned files
  setup _context do
    account = DummyData.account_prefix() |> create_account()

    %{
      account: account,
      file1: generate_fixture_owned_file(account, generate_temp_file("file"), "image/png"),
      file2: generate_fixture_owned_file(account, generate_temp_file("file2"), "image/png")
    }
  end

  test "delete if no row in other related tables", %{} do
    assert 2 == OwnedFile |> Repo.aggregate(:count)

    Storage.cleanup_nonreferred_files()

    assert 0 == OwnedFile |> Repo.aggregate(:count)
  end

  # TODO: Ideally should be tested with all the {
  #   RoomObject,
  #   Avatar(gltf_owned_file, bin_owned_file, :thumbnail_owned_file, ...),
  #   Asset(asset_owned_file, thumbnail_owned_file),
  #   ...
  # } combination
  # TODO: Test multiple rows deletion and remain

  test "not delete if OwnedFile is referred by AppConfig", %{
    file1: file,
    file2: non_referred_file
  } do
    %AppConfig{key: "foo", owned_file: file}
      |> Repo.insert!()

    cleanup_and_check(file, non_referred_file)
  end

  test "not delete if OwnedFile is referred by Asset", %{
    account: account,
    file1: file,
    file2: non_referred_file
  } do
    create_asset(%{
      account: account,
      thumbnail_owned_file: file
    })

    cleanup_and_check(file, non_referred_file)
  end

  test "not delete if OwnedFile is referred by Avatar", %{
    account: account,
    file1: file,
    file2: non_referred_file
  } do
    %Avatar{}
      |> Avatar.changeset(
        account,
        %{
          gltf_owned_file: file,
          bin_owned_file: file
        },
        nil,
        nil,
        %{
          name: "Test Avatar"
        }
      )
      |> Repo.insert!()

    cleanup_and_check(file, non_referred_file)
  end

  test "not delete if OwnedFile is referred by AvatarListing", %{
    account: account,
    file1: file,
    file2: non_referred_file
  } do
    avatar = %Avatar{}
      |> Avatar.changeset(
        account,
        %{
          gltf_owned_file: file,
          bin_owned_file: file
        },
        nil,
        nil,
        %{
          name: "Test Avatar"
        }
      )
      |> Repo.insert!()

    %AvatarListing{}
      |> AvatarListing.changeset_for_listing_for_avatar(
           avatar,
           %{}
         )
      |> Repo.insert!()

    # The Avatar refers to file so delete it for
    # AvatarListing test
    Repo.delete_all(Avatar)

    cleanup_and_check(file, non_referred_file)
  end

  test "not delete if OwnedFile is referred by Project", %{
    account: account,
    file1: file,
    file2: non_referred_file
  } do
    create_project(%{
      account: account,
      project_owned_file: file,
      thumbnail_owned_file: file
    })

    cleanup_and_check(file, non_referred_file)
  end

  test "not delete if OwnedFile is referred by Scene", %{
    account: account,
    file1: file,
    file2: non_referred_file
  } do
    create_scene(%{account: account, owned_file: file})

    cleanup_and_check(file, non_referred_file)
  end

  test "not delete if OwnedFile is referred by SceneListing", %{
    account: account,
    file1: file,
    file2: non_referred_file
  } do
    {:ok, scene: scene} = create_scene(%{account: account, owned_file: file})
    create_scene_listing(%{scene: scene})

    # The Scene refers to file so delete it for
    # SceneListing test
    Repo.delete_all(Scene)

    cleanup_and_check(file, non_referred_file)
  end

  test "not delete if OwnedFile is referred by RoomObject", %{
    account: account,
    file1: file1,
    file2: file2
  } do
    # Make the third owned file that is not referred
    non_referred_file = generate_temp_owned_file(account)

    {:ok, scene: scene} = create_scene(%{account: account, owned_file: file1})
    {:ok, hub: hub} = create_hub(%{scene: scene})

    %RoomObject{
      account: account,
      gltf_node: create_gltf_node_with_media("https://hubs.local:4000/files/#{file2.owned_file_uuid}.glb?token=xxx"),
      hub: hub,
      object_id: "fake id"
    }
      |> Repo.insert!()

    # file1 is referred by Scene and file2 is referred by RoomObject so
    # they will be remained. The third owned file is not referred and
    # it will be deleted.

    referred_query = from(
      f in OwnedFile,
      where: f.owned_file_uuid in [^file1.owned_file_uuid, ^file2.owned_file_uuid]
    )

    non_referred_query = from(
      f in OwnedFile,
      where: f.owned_file_uuid == ^non_referred_file.owned_file_uuid
    )

    non_referred_owned_file_query = from(
      f in NonReferredOwnedFile,
      where: f.owned_file_uuid == ^non_referred_file.owned_file_uuid
    )

    assert 3 == Repo.aggregate(OwnedFile, :count)
    assert 2 == Repo.aggregate(referred_query, :count)
    assert 1 == Repo.aggregate(non_referred_query, :count)
    assert 0 == Repo.aggregate(NonReferredOwnedFile, :count)
    assert 0 == Repo.aggregate(non_referred_owned_file_query, :count)

    Storage.cleanup_nonreferred_files()

    assert 2 == Repo.aggregate(OwnedFile, :count)
    assert 2 == Repo.aggregate(referred_query, :count)
    assert 0 == Repo.aggregate(non_referred_query, :count)
    assert 1 == Repo.aggregate(NonReferredOwnedFile, :count)
    assert 1 == Repo.aggregate(non_referred_owned_file_query, :count)
  end

  test "no fail with no HUBS_components in RoomObject.gltf_node", %{
    account: account,
    file1: file,
    file2: non_referred_file
  } do
    {:ok, scene: scene} = create_scene(%{account: account, owned_file: file})
    {:ok, hub: hub} = create_hub(%{scene: scene})

    %RoomObject{
      account: account,
      gltf_node: %{extensions: %{}} |> Jason.encode!(),
      hub: hub,
      object_id: "fake id"
    }
      |> Repo.insert!()

    cleanup_and_check(file, non_referred_file)
  end

  test "no fail with public resource url in media.src", %{
    account: account,
    file1: file,
    file2: non_referred_file
  } do
    {:ok, scene: scene} = create_scene(%{account: account, owned_file: file})
    {:ok, hub: hub} = create_hub(%{scene: scene})

    %RoomObject{
      account: account,
      gltf_node: create_gltf_node_with_media("https://www.example.com/some_image.png"),
      hub: hub,
      object_id: "fake id"
    }
      |> Repo.insert!()

    cleanup_and_check(file, non_referred_file)
  end

  defp create_gltf_node_with_media(src) do
    %{
      extensions: %{
        HUBS_components: %{
          media: %{
            src: src
          }
        }
      }
    }
      |> Jason.encode!()
  end

  defp cleanup_and_check(referred_file, non_referred_file) do
    # Assume only two owned files are made and one (the first argument)
    # of them is referred by somewhere in the related tables while
    # the other one (the second argument) is not.
    # Test cases that don't match this assumption should use custom
    # run and check.

    referred_query = from(
      f in OwnedFile,
      where: f.owned_file_uuid == ^referred_file.owned_file_uuid
    )

    non_referred_query = from(
      f in OwnedFile,
      where: f.owned_file_uuid == ^non_referred_file.owned_file_uuid
    )

    non_referred_owned_file_query = from(
      f in NonReferredOwnedFile,
      where: f.owned_file_uuid == ^non_referred_file.owned_file_uuid
    )

    assert 2 == Repo.aggregate(OwnedFile, :count)
    assert 1 == Repo.aggregate(referred_query, :count)
    assert 1 == Repo.aggregate(non_referred_query, :count)
    assert 0 == Repo.aggregate(NonReferredOwnedFile, :count)

    Storage.cleanup_nonreferred_files()

    # An OwnedFile that is not referred should be deleted so total
    # OwnedFile count should be one.

    assert 1 == Repo.aggregate(OwnedFile, :count)

    # A referred OwnedFile should be remained.

    assert 1 == Repo.aggregate(referred_query, :count)

    # A non-referred OwnedFile should be moved from OwnedFile to
    # NonReferredOwnedFile table.

    assert 1 == Repo.aggregate(NonReferredOwnedFile, :count)
    assert 1 == Repo.aggregate(non_referred_owned_file_query, :count)
    assert 0 == Repo.aggregate(non_referred_query, :count)

    # Check if the moved row keeps the same value
    read_data = Repo.one!(non_referred_owned_file_query)

    # Question: Any more elegant way to check?
    assert non_referred_file.owned_file_id == read_data.owned_file_id
    assert non_referred_file.owned_file_uuid == read_data.owned_file_uuid
    assert non_referred_file.key == read_data.key
    assert non_referred_file.content_type == read_data.content_type
    assert non_referred_file.content_length == read_data.content_length
    assert non_referred_file.account_id == read_data.account_id
  end
end
