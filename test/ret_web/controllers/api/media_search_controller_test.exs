defmodule RetWeb.SceneControllerTest do
  use RetWeb.ConnCase
  import Ret.TestHelpers

  setup [:create_account, :create_owned_file, :create_avatar]

  setup do
    on_exit(fn ->
      clear_all_stored_files()
    end)
  end

  @tag :authenticated
  test "Search for avatar by user works for a user's own avatars", %{conn: conn, account: account, avatar: avatar} do
    resp =
      conn
      |> get(api_v1_media_search_path(conn, :index), %{
        source: "avatars",
        user: account.account_id |> Integer.to_string()
      })
      |> json_response(200)

    # there should only be one entry
    [entry] = resp["entries"]

    # and it should be the avatar we just created
    assert entry["id"] == avatar.avatar_sid
  end

  test "Search for avatar by user does not work another user's avatars", %{conn: conn, account: account} do
    {:ok, token, _claims} =
      "test2@mozilla.com"
      |> Ret.Account.account_for_email()
      |> Ret.Guardian.encode_and_sign()

    conn
    |> Plug.Conn.put_req_header("authorization", "bearer: " <> token)
    |> get(api_v1_media_search_path(conn, :index), %{
      source: "avatars",
      user: account.account_id |> Integer.to_string()
    })
    |> response(401)
  end
end
