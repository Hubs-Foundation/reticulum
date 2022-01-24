defmodule RetWeb.PageControllerTest do
  use RetWeb.ConnCase

  test "redirect to non-existent entry code", %{conn: conn} do
    resp = conn |> get("/link/123456")
    assert resp |> response(404)
  end

  test "redirect with existing entry code", %{conn: conn} do
    {:ok, hub} = Ret.Hub.create_new_room(%{"name" => "test hub"}, true)
    resp = conn |> get("/link/#{hub.entry_code}")
    assert resp |> response(302)
  end

  test "redirect fails with expired entry code", %{conn: conn} do
    {:ok, hub} = Ret.Hub.create_new_room(%{"name" => "test hub"}, true)

    hub
    |> Ecto.Changeset.change(
      entry_code_expires_at:
        Timex.now()
        |> DateTime.truncate(:second)
    )
    |> Ret.Repo.update!()

    resp = conn |> get("/link/#{hub.entry_code}")
    assert resp |> response(404)
  end

  test "pages are served with csp headers", %{conn: conn} do
    resp = conn |> get("/")
    [csp] = resp |> Plug.Conn.get_resp_header("content-security-policy")

    assert csp |> String.contains?("google-analytics")
  end
end
