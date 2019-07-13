defmodule RetWeb.HealthController do
  use RetWeb, :controller
  import ExUnit.Assertions
  import Ecto.Query

  def index(conn, _params) do
    # Check database
    from(h in Ret.Hub, limit: 1) |> Ret.Repo.one!()

    # Check page cache
    assert Ret.PageOriginWarmer.chunks_for_page(:hubs, "index.html") |> elem(1) |> Enum.count() > 0
    assert Ret.PageOriginWarmer.chunks_for_page(:hubs, "hub.html") |> elem(1) |> Enum.count() > 0
    assert Ret.PageOriginWarmer.chunks_for_page(:spoke, "index.html") |> elem(1) |> Enum.count() > 0

    # Check room routing
    assert Ret.RoomAssigner.get_available_host("") != nil

    send_resp(conn, 200, "ok")
  end
end
