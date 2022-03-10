defmodule RetWeb.PageControllerTest do
  use RetWeb.ConnCase

  test "does not redirect with an invalid hub sid", %{conn: conn} do
    resp = conn |> get("/link/123456")
    assert resp |> response(404)
  end

  test "redirect with a valid hub sid", %{conn: conn} do
    {:ok, hub} = Ret.Hub.create_new_room(%{"name" => "test hub"}, true)
    resp = conn |> get("/link/#{hub.hub_sid}")
    assert resp |> response(302)
  end
end
