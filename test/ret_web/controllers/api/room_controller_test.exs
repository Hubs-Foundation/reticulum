defmodule RetWeb.RoomControllerTest do
  use RetWeb.ConnCase
  import Ret.TestHelpers

  alias Ret.{Account, Hub, Repo, AccountFavorite}

  defp get_data(response) do
    response["data"]
  end

  setup _context do
    account_1 = Account.find_or_create_account_for_email("test@mozilla.com")
    account_2 = Account.find_or_create_account_for_email("test2@mozilla.com")
    scene = create_scene(account_1)

    %{
      account_1: account_1,
      account_2: account_2,
      scene: scene
    }
  end

  test "The room api returns favorited rooms", %{conn: conn, account_1: account_1, scene: scene} do
    {:ok, hub: private_hub} = create_hub(%{scene: scene})
    {:ok, hub: _private_hub} = create_hub(%{scene: scene})
    AccountFavorite.ensure_favorited(private_hub, account_1)

    [%{"room_id" => room_id}] =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_auth_header_for_account("test@mozilla.com")
      |> get(api_v1_room_path(conn, :index))
      |> json_response(200)
      |> get_data()

    assert room_id === private_hub.hub_sid
  end

  test "The room api returns the creator's rooms", %{conn: conn, account_1: account_1, scene: scene} do
    {:ok, hub: hub} = create_hub(%{scene: scene})

    # No rooms will be returned
    rooms =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_auth_header_for_account("test@mozilla.com")
      |> get(api_v1_room_path(conn, :index))
      |> json_response(200)
      |> get_data()

    assert Enum.empty?(rooms)

    # Now make Account 1 the creator
    hub
    |> Repo.preload(created_by_account: [])
    |> Hub.changeset_for_creator_assignment(account_1, hub.creator_assignment_token)
    |> Repo.update!()

    # Account 1 can see the room now
    [%{"room_id" => room_id}] =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_auth_header_for_account("test@mozilla.com")
      |> get(api_v1_room_path(conn, :index))
      |> json_response(200)
      |> get_data()

    assert room_id === hub.hub_sid

    # Account 2 still can't see the room
    rooms =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_auth_header_for_account("test2@mozilla.com")
      |> get(api_v1_room_path(conn, :index))
      |> json_response(200)
      |> get_data()

    assert Enum.empty?(rooms)
  end

  test "The room api returns public rooms", %{conn: conn, scene: scene} do
    {:ok, hub: hub} = create_hub(%{scene: scene})
    {:ok, hub: public_hub} = create_public_hub(%{scene: scene})
    assert hub.hub_sid != public_hub.hub_sid

    [%{"room_id" => room_id}] =
      conn
      |> put_req_header("content-type", "application/json")
      |> get(api_v1_room_path(conn, :index))
      |> json_response(200)
      |> get_data()

    assert room_id === public_hub.hub_sid
  end

  test "The room api requires auth for account-based queries", %{conn: conn, account_1: account_1, scene: scene} do
    {:ok, hub: hub} = create_hub(%{scene: scene})

    hub
    |> Repo.preload(created_by_account: [])
    |> Hub.changeset_for_creator_assignment(account_1, hub.creator_assignment_token)
    |> Repo.update!()

    {:ok, hub: public_hub} = create_public_hub(%{scene: scene})

    # Account 1 sees both rooms
    rooms =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_auth_header_for_account("test@mozilla.com")
      |> get(api_v1_room_path(conn, :index))
      |> json_response(200)
      |> get_data()

    assert length(rooms) === 2

    # Account 2 can only see the public room
    [%{"room_id" => room_id}] =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_auth_header_for_account("test2@mozilla.com")
      |> get(api_v1_room_path(conn, :index))
      |> json_response(200)
      |> get_data()

    assert room_id === public_hub.hub_sid
  end

  test "The room api does not return closed rooms", %{conn: conn, scene: scene} do
    {:ok, hub: hub} = create_public_hub(%{scene: scene})
    {:ok, hub: hub2} = create_public_hub(%{scene: scene})

    rooms =
      conn
      |> put_req_header("content-type", "application/json")
      |> get(api_v1_room_path(conn, :index))
      |> json_response(200)
      |> get_data()

    assert length(rooms) === 2

    # Close room 2
    hub2
    |> Hub.changeset_for_entry_mode(:deny)
    |> Repo.update!()

    [%{"room_id" => room_id}] =
      conn
      |> put_req_header("content-type", "application/json")
      |> get(api_v1_room_path(conn, :index))
      |> json_response(200)
      |> get_data()

    assert room_id === hub.hub_sid
  end

  test "The room api supports filtering by room ids", %{conn: conn, scene: scene} do
    {:ok, hub: hub} = create_public_hub(%{scene: scene})
    {:ok, hub: hub2} = create_public_hub(%{scene: scene})
    {:ok, hub: _hub3} = create_public_hub(%{scene: scene})

    rooms =
      conn
      |> put_req_header("content-type", "application/json")
      |> get(api_v1_room_path(conn, :index))
      |> json_response(200)
      |> get_data()

    assert length(rooms) === 3

    rooms =
      conn
      |> put_req_header("content-type", "application/json")
      |> get(api_v1_room_path(conn, :index), %{
        room_ids: [hub.hub_sid, hub2.hub_sid]
      })
      |> json_response(200)
      |> get_data()

    assert length(rooms) === 2

    [%{"room_id" => room_id}] =
      conn
      |> put_req_header("content-type", "application/json")
      |> get(api_v1_room_path(conn, :index), %{
        room_ids: [hub.hub_sid]
      })
      |> json_response(200)
      |> get_data()

    assert room_id === hub.hub_sid
  end

  test "The room api supports filtering by favorites", %{conn: conn, account_1: account_1, scene: scene} do
    {:ok, hub: public_hub} = create_public_hub(%{scene: scene})
    {:ok, hub: _public_hub2} = create_public_hub(%{scene: scene})
    AccountFavorite.ensure_favorited(public_hub, account_1)

    # Account 1 can see its favorites
    [%{"room_id" => room_id}] =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_auth_header_for_account("test@mozilla.com")
      |> get(api_v1_room_path(conn, :index), %{
        only_favorites: true
      })
      |> json_response(200)
      |> get_data()

    assert room_id === public_hub.hub_sid

    # Account 2 doesn't have any favorites
    rooms =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_auth_header_for_account("test2@mozilla.com")
      |> get(api_v1_room_path(conn, :index), %{
        only_favorites: true
      })
      |> json_response(200)
      |> get_data()

    assert Enum.empty?(rooms)
  end

  test "The room api paginates results", %{conn: conn, scene: scene} do
    for _n <- 1..50 do
      {:ok, _} = create_public_hub(%{scene: scene})
    end

    response =
      conn
      |> put_req_header("content-type", "application/json")
      |> get(api_v1_room_path(conn, :index))
      |> json_response(200)

    assert length(response["data"]) === 24
    assert response["meta"]["next_cursor"] === 2

    response =
      conn
      |> put_req_header("content-type", "application/json")
      |> get(api_v1_room_path(conn, :index), %{
        cursor: 3
      })
      |> json_response(200)

    assert length(response["data"]) === 2
    assert response["meta"]["next_cursor"] === nil
  end
end
