defmodule RetWeb.Plugs.Head do
  # Copy of Plug.Head that also adds metadata indicating the original request
  alias Plug.Conn

  def init([]), do: []

  def call(%Conn{method: "HEAD"} = conn, []) do
    %{conn | method: "GET"}
    |> Conn.put_req_header("x-original-method", "HEAD")
  end

  def call(conn, []), do: conn
end
