defmodule RetWeb.Api.V1.MetaController do
  use RetWeb, :controller

  def show(conn, params) do
    meta = Ret.Meta.get_meta(include_repo: Map.has_key?(params, "include_repo"))
    conn |> send_resp(200, meta |> Poison.encode!())
  end
end
