defmodule Ret.AvatarListingTest do
  use Ret.DataCase
  import Ret.TestHelpers

  alias Ret.{Repo, Account, Avatar, AvatarListing}

  setup do
    on_exit(fn ->
      clear_all_stored_files()
    end)
  end

  setup _context do
    account_1 = Account.find_or_create_account_for_email("test@mozilla.com")
    account_2 = Account.find_or_create_account_for_email("test2@mozilla.com")

    account_1_avatar_1 = create_avatar(account_1)
    account_1_avatar_2 = create_avatar(account_1)
    account_2_avatar_1 = create_avatar(account_2)

    %{
      account_1: account_1,
      account_2: account_2,
      account_1_avatar_1: account_1_avatar_1,
      account_1_avatar_2: account_1_avatar_2,
      account_2_avatar_1: account_2_avatar_1,
      account_1_avatar_1_listing_1: create_avatar_listing(account_1_avatar_1),
      account_1_avatar_1_listing_2: create_avatar_listing(account_1_avatar_1),
      account_1_avatar_2_listing_1: create_avatar_listing(account_1_avatar_2),
      account_2_avatar_1_listing_1: create_avatar_listing(account_2_avatar_1)
    }
  end

  test "can create an avatar listing", %{
    account_1_avatar_1: avatar,
    account_1_avatar_1_listing_1: listing
  } do
    assert listing.name == avatar.name
    assert listing.description == avatar.description
    assert listing.avatar_id == avatar.avatar_id
    assert listing.account_id == avatar.account_id
    assert listing.parent_avatar_listing_id == avatar.parent_avatar_listing_id
    assert listing.gltf_owned_file_id == avatar.gltf_owned_file_id
    assert listing.bin_owned_file_id == avatar.bin_owned_file_id
    assert listing.thumbnail_owned_file_id == avatar.thumbnail_owned_file_id
    assert listing.base_map_owned_file_id == avatar.base_map_owned_file_id
    assert listing.emissive_map_owned_file_id == avatar.emissive_map_owned_file_id
    assert listing.normal_map_owned_file_id == avatar.normal_map_owned_file_id
    assert listing.orm_map_owned_file_id == avatar.orm_map_owned_file_id
  end

  test "listings for an avatar become unlisted when deleting it", %{
    account_1: account_1,
    account_2: account_2,
    account_1_avatar_1: avatar,
    account_1_avatar_2: avatar2,
    account_2_avatar_1: account_2_avatar,
    account_1_avatar_1_listing_1: listing,
    account_1_avatar_1_listing_2: listing2,
    account_1_avatar_2_listing_1: other_avatars_listing,
    account_2_avatar_1_listing_1: other_accounts_listing
  } do
    avatar |> Avatar.delete_avatar_and_delist_listings()

    assert avatar.avatar_sid |> Avatar.avatar_or_avatar_listing_by_sid() == nil

    listing = AvatarListing |> Repo.get(listing.avatar_listing_id)
    listing2 = AvatarListing |> Repo.get(listing2.avatar_listing_id)
    other_avatars_listing = AvatarListing |> Repo.get(other_avatars_listing.avatar_listing_id)
    other_accounts_listing = AvatarListing |> Repo.get(other_accounts_listing.avatar_listing_id)

    assert listing.state == :delisted
    assert listing.avatar_id == nil
    assert listing.account_id == account_1.account_id

    assert listing2.state == :delisted
    assert listing2.avatar_id == nil
    assert listing2.account_id == account_1.account_id

    assert other_avatars_listing.state == :active
    assert other_avatars_listing.avatar_id == avatar2.avatar_id
    assert other_avatars_listing.account_id == account_1.account_id

    assert other_accounts_listing.state == :active
    assert other_accounts_listing.avatar_id == account_2_avatar.avatar_id
    assert other_accounts_listing.account_id == account_2.account_id
  end
end
