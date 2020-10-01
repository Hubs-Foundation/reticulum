defmodule RetWeb.ApiTokenAuthPipeline do
  @moduledoc false
  use Guardian.Plug.Pipeline,
    otp_app: :ret,
    module: Ret.ApiToken,
    error_handler: RetWeb.ApiTokenAuthErrorHandler

  plug(Guardian.Plug.VerifyHeader, realm: "Bearer", halt: false)
  plug(Guardian.Plug.LoadResource, allow_blank: true)
end

defmodule RetWeb.ApiTokenAuthErrorHandler do
  @moduledoc false
  import Plug.Conn

  def auth_error(conn, {failure_type, reason}, _opts) do
    conn = assign(conn, :auth_error, {failure_type, reason})
    conn
  end
end
