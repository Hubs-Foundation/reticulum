defmodule RetWeb.ApiTokenAuthPipeline do
  @moduledoc false
  use Guardian.Plug.Pipeline,
    otp_app: :ret,
    module: Ret.ApiToken,
    error_handler: RetWeb.ApiTokenAuthErrorHandler

  plug(Guardian.Plug.VerifyHeader, realm: "Bearer", claims: %{"typ" => "api"})
  plug(Guardian.Plug.LoadResource, allow_blank: true)
end

defmodule RetWeb.ApiTokenAuthErrorHandler do
  @moduledoc false
  import Plug.Conn

  def auth_error(conn, {type, _reason}, _opts) do
    # TODO
    IO.inspect("Error")
    IO.inspect(type)
    conn
  end
end
