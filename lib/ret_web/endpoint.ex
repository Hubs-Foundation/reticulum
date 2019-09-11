defmodule RetWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :ret
  use Sentry.Phoenix.Endpoint

  socket("/socket", RetWeb.SessionSocket, websocket: [check_origin: false])

  def get_cors_origins, do: Application.get_env(:ret, RetWeb.Endpoint)[:allowed_origins] |> String.split(",")

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phoenix.digest
  # when deploying your static files in production.
  plug(
    Plug.Static,
    at: "/",
    from: :ret,
    gzip: false,
    # Due to cloudfront, we want to include max-age in responses	
    cache_control_for_etags: "public, max-age=31536000",
    only: ~w(robots.txt favicon.ico hub-preview.png favicon-spoke.ico spoke-preview.png),
    headers: [{"access-control-allow-origin", "*"}]
  )

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
    plug(Phoenix.LiveReloader)
    plug(Phoenix.CodeReloader)
  end

  plug(Plug.RequestId)
  plug(Plug.Logger)

  plug(Plug.MethodOverride)

  # We need to handle HEAD for the FileController, but pushing the Plug.Head into the router pipeline
  # prevents matching on HEAD. So this new plug sends a GET as Plug.Head but also adds a x-original-method request
  # header
  plug(RetWeb.Plugs.Head)

  plug(CORSPlug, origin: &RetWeb.Endpoint.get_cors_origins/0)
  plug(RetWeb.Router)

  @doc """
  Callback invoked for dynamically configuring the endpoint.

  It receives the endpoint configuration and checks if
  configuration should be loaded from the system environment.
  """
  def init(_key, config) do
    if config[:load_from_system_env] do
      port = System.get_env("PORT") || raise "expected the PORT environment variable to be set"
      {:ok, Keyword.put(config, :http, [:inet6, port: port])}
    else
      {:ok, config}
    end
  end
end
