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

  test "anyone can query for public rooms", %{conn: conn} do
    account = create_random_account()
    scene = create_scene(account)
    {:ok, hub: public_hub} = create_public_hub(%{scene: scene})

    query = """
    query {
      publicRooms {
       entries {
         id
       }
      }
    }
    """

    res =
      conn
      |> post("/api/v2/graphiql", %{
        "query" => query,
        "variables" => "{}"
      })
      |> json_response(200)

    rooms = res["data"]["publicRooms"]["entries"]
    assert List.first(rooms)["id"] == public_hub.hub_sid
  end

  test "private room queries require authentication", %{conn: conn} do
    account = create_random_account()
    scene = create_scene(account)
    {:ok, hub: hub} = create_hub(%{scene: scene})
    hub
    |> Ret.Repo.preload(created_by_account: [])
    |> Ret.Hub.changeset_for_creator_assignment(account, hub.creator_assignment_token)
    |> Ret.Repo.update!()

    query = """
    query {
      myRooms {
       entries {
         id
       }
      }
    }
    """

    # Query without auth header
    res =
      conn
      |> post("/api/v2/graphiql", %{
        "query" => query,
        "variables" => "{}"
      })
      |> json_response(200)
    assert is_nil(res["data"]["myRooms"])
    error = List.first(res["errors"])
    assert error["message"] == "Not authorized"
    assert List.first(error["path"]) == "myRooms"

    # Query with auth header
    {:ok, token, _claims} = Ret.Guardian.encode_and_sign(account)
    auth_res =
      conn
      |> Plug.Conn.put_req_header("authorization", "bearer: " <> token)
      |> post("/api/v2/graphiql", %{
        "query" => query,
        "variables" => "{}"
      })
      |> json_response(200)
    rooms = auth_res["data"]["myRooms"]["entries"]
    assert List.first(rooms)["id"] == hub.hub_sid
  end
end
