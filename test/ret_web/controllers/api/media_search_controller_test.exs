defmodule RetWeb.MediaSearchControllerTest do
  use RetWeb.ConnCase
  import Ret.TestHelpers

  alias Ret.{Account, AccountFavorite, Hub, Repo}

  setup do
    on_exit(fn ->
      clear_all_stored_files()
    end)
  end

  setup _context do
    account_1 = Account.find_or_create_account_for_email("test@mozilla.com")
    account_2 = Account.find_or_create_account_for_email("test2@mozilla.com")
    account_3 = Account.find_or_create_account_for_email("test3@mozilla.com")

    scene_1 = create_scene(account_1)
    scene_2 = create_scene(account_2)
    {:ok, hub: private_hub} = create_hub(%{scene: scene_1})
    {:ok, hub: private_hub_2} = create_hub(%{scene: scene_1})
    {:ok, hub: public_hub} = create_public_hub(%{scene: scene_2})

    AccountFavorite.ensure_favorited(private_hub, account_1)
    AccountFavorite.ensure_favorited(private_hub_2, account_1)

    %{
      account_1: account_1,
      account_2: account_2,
      account_3: account_3,
      avatar_1: create_avatar(account_1),
      avatar_2: create_avatar(account_2),
      scene_1: scene_1,
      scene_2: scene_2,
      private_hub: private_hub,
      private_hub_2: private_hub_2,
      public_hub: public_hub
    }
  end

  defp search_avatars_for_account_id(conn, account_id) do
    conn
    |> get(api_v1_media_search_path(conn, :index), %{
      source: "avatars",
      user: account_id |> Integer.to_string()
    })
  end

  defp search_scenes_for_account_id(conn, account_id) do
    conn
    |> get(api_v1_media_search_path(conn, :index), %{
      source: "scenes",
      user: account_id |> Integer.to_string()
    })
  end

  defp search_favorites_for_account_id(conn, account_id) do
    conn
    |> get(api_v1_media_search_path(conn, :index), %{
      source: "favorites",
      user: account_id |> Integer.to_string()
    })
  end

  defp search_public_rooms(conn) do
    conn
    |> get(api_v1_media_search_path(conn, :index), %{
      source: "rooms",
      filter: "public"
    })
  end

  test "Search for a user's own avatars should return results if they have avatars", %{
    conn: conn,
    account_1: account,
    avatar_1: avatar
  } do
    resp =
      conn
      |> auth_with_account(account)
      |> search_avatars_for_account_id(avatar.account_id)
      |> json_response(200)

    # there should only be one entry
    [entry] = resp["entries"]

    # and the avatar should belong to the account we authed as
    assert entry["id"] == avatar.avatar_sid
    assert avatar.account_id == account.account_id
  end

  test "Search for a user's own avatars should return an empty list if they have no avatars", %{
    conn: conn,
    account_3: account
  } do
    resp =
      conn
      |> auth_with_account(account)
      |> get(api_v1_media_search_path(conn, :index), %{
        source: "avatars",
        user: account.account_id |> Integer.to_string()
      })
      |> json_response(200)

    # There should be no entries
    assert resp["entries"] == []
  end

  test "Search for another user's avatars should return a 401", %{
    conn: conn,
    avatar_1: avatar_1,
    account_2: account
  } do
    conn
    |> auth_with_account(account)
    |> get(api_v1_media_search_path(conn, :index), %{
      source: "avatars",
      user: avatar_1.account_id |> Integer.to_string()
    })
    |> response(401)
  end

  test "Search for a user's own scenes should return results if they have scenes", %{
    conn: conn,
    account_1: account,
    scene_1: scene
  } do
    resp =
      conn
      |> auth_with_account(account)
      |> search_scenes_for_account_id(scene.account_id)
      |> json_response(200)

    # there should only be one entry
    [entry] = resp["entries"]

    # and the scene should belong to the account we authed as
    assert entry["id"] == scene.scene_sid
    assert scene.account_id == account.account_id
  end

  test "Search for a user's own scenes should return an empty list if they have no scenes", %{
    conn: conn,
    account_3: account
  } do
    resp =
      conn
      |> auth_with_account(account)
      |> get(api_v1_media_search_path(conn, :index), %{
        source: "scenes",
        user: account.account_id |> Integer.to_string()
      })
      |> json_response(200)

    # There should be no entries
    assert resp["entries"] == []
  end

  test "Search for another user's scenes should return a 401", %{
    conn: conn,
    scene_1: scene_1,
    account_2: account
  } do
    conn
    |> auth_with_account(account)
    |> get(api_v1_media_search_path(conn, :index), %{
      source: "scenes",
      user: scene_1.account_id |> Integer.to_string()
    })
    |> response(401)
  end

  test "Search for a user's own favorites should return results if they have favorites", %{
    conn: conn,
    account_1: account,
    private_hub: private_hub,
    private_hub_2: private_hub_2
  } do
    resp =
      conn
      |> auth_with_account(account)
      |> search_favorites_for_account_id(account.account_id)
      |> json_response(200)

    entries = resp["entries"]
    assert length(entries) == 2

    assert length(
             Enum.filter(entries, fn e ->
               e["id"] == private_hub.hub_sid && e["type"] == "room"
             end)
           ) == 1

    assert length(
             Enum.filter(entries, fn e ->
               e["id"] == private_hub_2.hub_sid && e["type"] == "room"
             end)
           ) == 1
  end

  test "Search for a user's own favorites should not return closed hubs", %{
    conn: conn,
    account_1: account,
    private_hub: private_hub,
    private_hub_2: private_hub_2
  } do
    resp =
      conn
      |> auth_with_account(account)
      |> search_favorites_for_account_id(account.account_id)
      |> json_response(200)

    entries = resp["entries"]
    assert length(entries) == 2
    assert length(Enum.filter(entries, fn e -> e["id"] == private_hub.hub_sid end)) == 1
    assert length(Enum.filter(entries, fn e -> e["id"] == private_hub_2.hub_sid end)) == 1

    # Close the first hub
    private_hub |> Hub.changeset_for_entry_mode(:deny) |> Repo.update!()

    resp =
      conn
      |> auth_with_account(account)
      |> search_favorites_for_account_id(account.account_id)
      |> json_response(200)

    # there should only be one entry
    [entry] = resp["entries"]
    assert entry["id"] == private_hub_2.hub_sid
    assert entry["type"] == "room"
  end

  test "Search for a user's own favorites should return an empty list if they have no favorites",
       %{
         conn: conn,
         account_3: account
       } do
    resp =
      conn
      |> auth_with_account(account)
      |> get(api_v1_media_search_path(conn, :index), %{
        source: "favorites",
        user: account.account_id |> Integer.to_string()
      })
      |> json_response(200)

    # There should be no entries
    assert resp["entries"] == []
  end

  test "Search for another user's favorites should return a 401", %{
    conn: conn,
    account_1: account,
    account_2: account_2
  } do
    conn
    |> auth_with_account(account)
    |> get(api_v1_media_search_path(conn, :index), %{
      source: "favorites",
      user: account_2.account_id |> Integer.to_string()
    })
    |> response(401)
  end

  test "Search for public rooms should only return public rooms", %{
    conn: conn,
    public_hub: public_hub
  } do
    resp =
      conn
      |> search_public_rooms()
      |> json_response(200)

    # there should only be one entry
    [entry] = resp["entries"]

    # and the hub should be the favorited hub
    assert entry["id"] == public_hub.hub_sid
    assert entry["type"] == "room"
  end
end
