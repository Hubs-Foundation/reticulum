defmodule RetWeb.Plugs.AddCSP do
  def init(default), do: default

  def call(conn, _options) do
    policy = Application.get_env(:ret, RetWeb.Plugs.AddCSP)[:content_security_policy]

    if policy do
      conn |> Plug.Conn.put_resp_header("content-security-policy", policy)
    else
      conn
    end
  end
end
