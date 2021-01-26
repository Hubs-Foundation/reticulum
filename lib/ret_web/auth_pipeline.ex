defmodule RetWeb.Guardian.AuthPipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :ret,
    module: Ret.Guardian,
    error_handler: RetWeb.Guardian.AuthErrorHandler

  plug(Guardian.Plug.VerifyHeader, realm: "Bearer")
  plug(Guardian.Plug.VerifyCookie, exchange_from: "access")
  plug(Guardian.Plug.EnsureAuthenticated)
  plug(Guardian.Plug.LoadResource)
end
