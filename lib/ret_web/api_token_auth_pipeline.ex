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

  def auth_error(conn, {failure_type, %ArgumentError{message: reason}}, _opts) do
    # TODO: Is assigns the right place for this info?
    assign(conn, :auth_error, {failure_type, reason})
  end

  def auth_error(conn, {failure_type, reason}, _opts) do
    assign(conn, :auth_error, {failure_type, reason})
  end
end
