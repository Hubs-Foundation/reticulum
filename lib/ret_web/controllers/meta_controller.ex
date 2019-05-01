defmodule RetWeb.Api.V1.MetaController do
  use RetWeb, :controller

  def show(conn, _params) do
    meta = Ret.Meta.get_meta()
    conn |> send_resp(200, meta |> Poison.encode!())
  end
end
