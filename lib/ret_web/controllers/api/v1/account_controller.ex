defmodule RetWeb.Api.V1.AccountController do
  use RetWeb, :controller

  alias Ret.{Account, Repo}

  def create(conn, params) do
    account = Guardian.Plug.current_resource(conn)

    if account.is_admin do
      exec_create(conn, params)
    else
      conn |> send_resp(401, "unauthorized")
    end
  end

  defp exec_create(conn, %{"data" => data}) do
    conn |> send_resp(200, "OK")
    # case result do
    #  :ok -> render(conn, "create.json", hub: hub)
    #  :error -> conn |> send_resp(422, "invalid hub")
    # end
  end

  defp exec_create(conn, _invalid_params) do
    conn |> send_resp(400, "Missing 'data' property in POST")
  end
end
