defmodule RetWeb.Api.V1.MetaController do
  use RetWeb, :controller

  plug(RetWeb.Plugs.RateLimit when action in [:show])

  def show(conn, _params) do
    meta = Ret.Meta.get_meta()
    conn |> send_resp(200, meta |> Poison.encode!())
  end
end
