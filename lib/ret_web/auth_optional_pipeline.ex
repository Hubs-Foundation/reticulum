defmodule RetWeb.Guardian.AuthOptionalPipeline do
  @moduledoc false
  use Guardian.Plug.Pipeline,
    otp_app: :ret,
    module: Ret.Guardian,
    error_handler: RetWeb.Guardian.AuthErrorHandler

  plug Guardian.Plug.VerifyHeader, realm: "Bearer"
  plug Guardian.Plug.LoadResource, allow_blank: true
end
