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
      |> post("/api/v2/graphiql", %{
        "query" => @query_public_rooms
      })
      |> json_response(200)

    rooms = res["data"]["publicRooms"]["entries"]
    assert List.first(rooms)["id"] == public_hub.hub_sid
  end

  test "cannot query my rooms without authentication", %{conn: conn, account: account, hub: hub} do
    assign_creator(hub, account)

    # Query without auth header
    res =
      conn
      |> post("/api/v2/graphiql", %{
        "query" => @query_my_rooms
      })
      |> json_response(200)

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
      |> post("/api/v2/graphiql", %{
        "query" => @query_my_rooms
      })
      |> json_response(200)

    rooms = auth_res["data"]["myRooms"]["entries"]
    assert List.first(rooms)["id"] == hub.hub_sid
  end

  test "my rooms only returns my own rooms", %{conn: conn, account: account, account2: account2, hub: hub} do
    assign_creator(hub, account)

    auth_res =
      conn
      |> put_auth_header_for_account(account2)
      |> post("/api/v2/graphiql", %{
        "query" => @query_my_rooms
      })
      |> json_response(200)

    rooms = auth_res["data"]["myRooms"]["entries"]
    assert Enum.empty?(rooms)
  end

  test "cannot query favorite rooms without authentication", %{conn: conn, account: account, hub: hub} do
    Ret.AccountFavorite.ensure_favorited(hub, account)

    # Query without auth header
    res =
      conn
      |> post("/api/v2/graphiql", %{
        "query" => @query_favorite_rooms
      })
      |> json_response(200)

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
      |> post("/api/v2/graphiql", %{
        "query" => @query_favorite_rooms
      })
      |> json_response(200)

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
      |> post("/api/v2/graphiql", %{
        "query" => @query_favorite_rooms
      })
      |> json_response(200)

    rooms = res["data"]["favoriteRooms"]["entries"]
    assert Enum.empty?(rooms)
  end
end
