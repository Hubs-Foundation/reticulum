defmodule RetWeb.MediaSearchControllerTest do
  use RetWeb.ConnCase
  import Ret.TestHelpers

  alias Ret.Account

  setup do
    on_exit(fn ->
      clear_all_stored_files()
    end)
  end

  setup _context do
    account_1 = Account.account_for_email("test@mozilla.com")
    account_2 = Account.account_for_email("test2@mozilla.com")
    account_3 = Account.account_for_email("test3@mozilla.com")

    %{
      account_1: account_1,
      account_2: account_2,
      account_3: account_3,
      avatar_1: create_avatar(account_1),
      avatar_2: create_avatar(account_2)
    }
  end

  defp search_avatars_for_account_id(conn, account_id) do
    conn
    |> get(api_v1_media_search_path(conn, :index), %{
      source: "avatars",
      user: account_id |> Integer.to_string()
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

    # and the avatar should beelong to the account we authed as
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
end
