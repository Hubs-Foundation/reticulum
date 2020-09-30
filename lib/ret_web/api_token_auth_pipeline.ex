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

  def auth_error(conn, {:invalid_token, :token_expired}, opts) do
    IO.inspect("token_expired")
    # Need to prevent halting so that we can return these errors in graphql response
    # https://github.com/ueberauth/guardian/issues/401#issuecomment-367756347
    opts = Keyword.put(opts, :halt, false)
    conn
  end
  def auth_error(conn, {type, reason}, _opts) do
    IO.inspect(type)
    IO.inspect(reason)
    conn
  end
end
