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

  test "pages are served with csp headers", %{conn: conn} do
    resp = conn |> get("/")
    [csp] = resp |> Plug.Conn.get_resp_header("content-security-policy")

    assert csp |> String.contains?("google-analytics")
  end
end
