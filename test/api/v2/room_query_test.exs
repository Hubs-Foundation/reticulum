defmodule RoomQueryTest do
  @moduledoc """
  Test absinthe queries on rooms
  """

  use ExUnit.Case
  use RetWeb.ConnCase
  import Ret.TestHelpers
  alias Ret.Api.TokenUtils

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
    query ($page: Int, $page_size: Int){
      myRooms (page: $page, page_size: $page_size){
       entries {
         id
       }
       total_entries
       total_pages
       page_number
       page_size
      }
    }
  """

  defp do_graphql_action(conn, query, variables \\ %{}) do
    conn
    |> post("/api/v2_alpha/", %{
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
    {:ok, token, _claims} = TokenUtils.gen_token_for_account(account)
    {:ok, app_token, _claims} = TokenUtils.gen_app_token()

    %{
      account: account,
      account2: account2,
      scene: scene,
      hub: hub,
      public_hub: public_hub,
      token: token,
      app_token: app_token
    }
  end

  test "Cannot query without a token", %{conn: conn} do
    res = conn |> do_graphql_action(@query_public_rooms)
    assert hd(res["errors"])["type"] === "api_access_token_not_found"
  end

  test "Can query public rooms with app token", %{conn: conn, public_hub: public_hub, app_token: app_token} do
    res =
      conn
      |> put_auth_header_for_token(app_token)
      |> do_graphql_action(@query_public_rooms)

    rooms = res["data"]["publicRooms"]["entries"]
    assert List.first(rooms)["id"] == public_hub.hub_sid
  end

  test "Cannot query my rooms with app token without specifying account", %{
    conn: conn,
    account: account,
    hub: hub,
    app_token: app_token
  } do
    assign_creator(hub, account)

    res =
      conn
      |> put_auth_header_for_token(app_token)
      |> do_graphql_action(@query_my_rooms)

    assert hd(res["errors"])["type"] === "not_implemented"
  end

  test "Can query my rooms with appropriate token", %{
    conn: conn,
    account: account,
    hub: hub,
    token: token
  } do
    assign_creator(hub, account)

    auth_res =
      conn
      |> put_auth_header_for_token(token)
      |> do_graphql_action(@query_my_rooms)

    rooms = auth_res["data"]["myRooms"]["entries"]
    assert List.first(rooms)["id"] == hub.hub_sid
  end

  test "my rooms only returns my own rooms", %{conn: conn, account2: account2, hub: hub, token: token} do
    assign_creator(hub, account2)

    auth_res =
      conn
      |> put_auth_header_for_token(token)
      |> do_graphql_action(@query_my_rooms)

    rooms = auth_res["data"]["myRooms"]["entries"]
    assert Enum.empty?(rooms)
  end

  test "The room query api paginates results", %{
    conn: conn,
    scene: scene,
    account: account,
    token: token
  } do
    for _n <- 1..50 do
      {:ok, hub: hub} = create_hub(%{scene: scene})
      assign_creator(hub, account)
    end

    response =
      conn
      |> put_auth_header_for_token(token)
      |> do_graphql_action(@query_my_rooms)

    assert length(response["data"]["myRooms"]["entries"]) === response["data"]["myRooms"]["page_size"]
  end

  test "The room query api paginates results 2", %{
    conn: conn,
    scene: scene,
    account: account,
    token: token
  } do
    for _n <- 1..50 do
      {:ok, hub: hub} = create_hub(%{scene: scene})
      assign_creator(hub, account)
    end

    response =
      conn
      |> put_auth_header_for_token(token)
      |> do_graphql_action(@query_my_rooms, %{page: 3, page_size: 24})

    assert length(response["data"]["myRooms"]["entries"]) === 2
  end
end
