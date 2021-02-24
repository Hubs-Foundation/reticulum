defmodule RetWeb.Guardian.AuthPipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :ret,
    module: Ret.Guardian,
    error_handler: RetWeb.Guardian.AuthErrorHandler

  plug(Guardian.Plug.VerifyHeader, realm: "Bearer")
  # TODO: Move configuration elsewhere
  plug Plug.Session,
    store: :cookie,
    key: "_ret_session",
    # TODO: Provide real salts (safely)
    encryption_salt: "8XD1Tqa223TZ/1pErZGaKDWLbnEFfdo/",
    signing_salt: "ZXAeUzIQJdzKT5WmxUQpROOL7eqK1FsX",
    key_length: 64,
    log: :debug

  plug(RetWeb.Plugs.DecryptAuthCookieIntoSession)
  plug(Guardian.Plug.VerifySession)
  plug(Guardian.Plug.EnsureAuthenticated)
  plug(Guardian.Plug.LoadResource)
end
