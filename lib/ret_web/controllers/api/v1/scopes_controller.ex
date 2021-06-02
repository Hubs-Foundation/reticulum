defmodule RetWeb.Api.V1.ScopesController do
  use RetWeb, :controller

  alias Ret.Api.Scopes

  # Get available scopes
  def index(conn, _params) do
    IO.puts("get scopes")
    IO.puts("SCOPES")

    conn
    |> put_resp_header("content-type", "application/json")
    |> put_status(200)
    |> render("show.json", scopes: Scopes.all_scopes())
  end
end
