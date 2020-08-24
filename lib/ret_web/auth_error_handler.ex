defmodule RetWeb.Guardian.AuthErrorHandler do
  @moduledoc false
  import Plug.Conn

  def auth_error(conn, {type, _reason}, _opts) do
    body = Poison.encode!(%{error: to_string(type)})
    send_resp(conn, 401, body)
    # TODO: GraphQL endpoint errors should be formatted with absinthe_plug
    #  "data" => %{ "action" => null  }
    #  "errors" => [
    #    %{
    #      "message" => "Some error messages",
    #      "locations" => [%{"line" => 1, "column" => 2}]
    #    }
    #  ]
  end
end
