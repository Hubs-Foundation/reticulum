defmodule RoomQueryTest do
  @moduledoc """
  Test absinthe queries on rooms
  """

  use ExUnit.Case
  use RetWeb.ConnCase
  import Ret.TestHelpers

  setup_all do
    Absinthe.Test.prime(RetWeb.Schema)
  end

  @query_public_rooms """
    query {
      publicRooms {
       entries {
         id
       }
      }
    }
  """

  @query_my_rooms """
    query {
      myRooms {
       entries {
         id
       }
      }
    }
  """

  @query_favorite_rooms """
    query {
      favoriteRooms {
       entries {
         id
       }
      }
    }
  """

  @mutation_create_room """
    mutation MyCooLmutatuon($roomName: String!){
      createRoom (name: $roomName) {
        id,
        name
      }
    }
  """

  defp do_graphql_action(conn, query, variables \\ %{}) do
    conn
    |> post("/api/v2/", %{
      "query" => "#{query}",
      "variables" => variables
    })
    |> json_response(200)
  end

  setup _context do
    account = create_random_account()
    account2 = create_random_account()
    scene = create_scene(account)
    {:ok, hub: hub} = create_hub(%{scene: scene})
    {:ok, hub: public_hub} = create_public_hub(%{scene: scene})

    %{
      account: account,
      account2: account2,
      hub: hub,
      public_hub: public_hub
    }
  end

  test "anyone can query for public rooms", %{conn: conn, public_hub: public_hub} do
    res =
      conn
      |> do_graphql_action(@query_public_rooms)

    rooms = res["data"]["publicRooms"]["entries"]
    assert List.first(rooms)["id"] == public_hub.hub_sid
  end

  test "cannot query my rooms without authentication", %{conn: conn, account: account, hub: hub} do
    assign_creator(hub, account)

    res =
      conn
      |> do_graphql_action(@query_my_rooms)

    assert is_nil(res["data"]["myRooms"])
    error = List.first(res["errors"])
    assert error["message"] == "Not authorized"
    assert List.first(error["path"]) == "myRooms"
  end

  test "anyone can query for their own rooms when authenticated", %{
    conn: conn,
    account: account,
    hub: hub
  } do
    assign_creator(hub, account)

    auth_res =
      conn
      |> put_auth_header_for_account(account)
      |> do_graphql_action(@query_my_rooms)

    rooms = auth_res["data"]["myRooms"]["entries"]
    assert List.first(rooms)["id"] == hub.hub_sid
  end

  test "my rooms only returns my own rooms", %{conn: conn, account: account, account2: account2, hub: hub} do
    assign_creator(hub, account)

    auth_res =
      conn
      |> put_auth_header_for_account(account2)
      |> do_graphql_action(@query_my_rooms)

    rooms = auth_res["data"]["myRooms"]["entries"]
    assert Enum.empty?(rooms)
  end

  test "cannot query favorite rooms without authentication", %{conn: conn, account: account, hub: hub} do
    Ret.AccountFavorite.ensure_favorited(hub, account)

    res =
      conn
      |> do_graphql_action(@query_favorite_rooms)

    assert is_nil(res["data"]["favoriteRooms"])
    error = List.first(res["errors"])
    assert error["message"] == "Not authorized"
    assert List.first(error["path"]) == "favoriteRooms"
  end

  test "anyone can query favorite rooms when authenticated", %{conn: conn, account: account, hub: hub} do
    Ret.AccountFavorite.ensure_favorited(hub, account)

    res =
      conn
      |> put_auth_header_for_account(account)
      |> do_graphql_action(@query_favorite_rooms)

    rooms = res["data"]["favoriteRooms"]["entries"]
    assert List.first(rooms)["id"] == hub.hub_sid
  end

  test "favorite rooms only returns your own favorites", %{
    conn: conn,
    account: account,
    account2: account2,
    hub: hub
  } do
    Ret.AccountFavorite.ensure_favorited(hub, account)

    res =
      conn
      |> put_auth_header_for_account(account2)
      |> do_graphql_action(@query_favorite_rooms)

    rooms = res["data"]["favoriteRooms"]["entries"]
    assert Enum.empty?(rooms)
  end

  test "anyone can create a room", %{
    conn: conn
  } do
    roomName = "my fun room"
    res =
      conn
      |> do_graphql_action(@mutation_create_room, %{roomName: roomName})

    id = res["data"]["createRoom"]["id"]
    assert !is_nil(id)
    hub = Ret.Repo.get_by(Ret.Hub, hub_sid: id)
    assert hub.name == res["data"]["createRoom"]["name"]
    assert hub.name == roomName
  end

  test "Creating a room while authenticated assigns the creator", %{
    conn: conn,
    account: account
  } do
    res =
      conn
      |> put_auth_header_for_account(account)
      |> do_graphql_action(@mutation_create_room, %{roomName: "my fun room"})

    hub = Ret.Repo.get_by(Ret.Hub, hub_sid: res["data"]["createRoom"]["id"])
    assert hub.created_by_account_id == account.account_id
  end
end
