defmodule RetWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :ret
  use Sentry.Phoenix.Endpoint

  socket("/socket", RetWeb.SessionSocket, websocket: [check_origin: { RetWeb.Endpoint, :allowed_origin?, [] } ] )

  def get_cors_origins, do: Application.get_env(:ret, RetWeb.Endpoint)[:allowed_origins] |> String.split(",")
  def get_cors_origin_urls, do: get_cors_origins() |> Enum.filter(&(&1 != "*")) |> Enum.map(&URI.parse/1)

  def allowed_origin?(url) do
    if get_cors_origins() === ["*"] do
      true
    else
      get_cors_origin_urls() |> Enum.any?(fn o ->
        o.host == url.host && o.port == url.port && o.scheme == url.scheme
      end)
    end
  end

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

  plug(
    Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library(),
    length: 157_286_400,
    read_timeout: 300_000
  )

  plug(Plug.MethodOverride)

  # We need to handle HEAD for the FileController, but pushing the Plug.Head into the router pipeline
  # prevents matching on HEAD. So this new plug sends a GET as Plug.Head but also adds a x-original-method request
  # header
  plug(RetWeb.Head)

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
