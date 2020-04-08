defmodule RetWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :ret
  use Sentry.Phoenix.Endpoint

  socket("/socket", RetWeb.SessionSocket, websocket: [check_origin: {RetWeb.Endpoint, :allowed_origin?, []}])

  def get_cors_origins, do: Application.get_env(:ret, RetWeb.Endpoint)[:allowed_origins] |> String.split(",")
  def get_cors_origin_urls, do: get_cors_origins() |> Enum.filter(&(&1 != "*")) |> Enum.map(&URI.parse/1)

  def local_address_ranges(), do: [CIDR.parse("192.168.0.0/16"), CIDR.parse("10.0.0.0/8"), CIDR.parse("172.16.0.0/12")]

  defp is_ok?(value) do
    case value do
      {:ok, _} -> true
      _ -> false
    end
  end

  def allowed_origin?(url) when is_binary(url), do: allowed_origin?(URI.parse(url))

  def allowed_origin?(%URI{host: host, port: port, scheme: scheme}) do
    cond do
      get_cors_origins() === ["*"] -> true
      Application.get_env(:ret, RetWeb.Endpoint)[:allow_local_origins] ->
        Enum.any?(local_address_ranges(), fn(range) -> is_ok?(CIDR.match(range, host)) end)
      true -> get_cors_origin_urls() |> Enum.any?(&(&1.host == host && &1.port == port && &1.scheme == scheme))
    end
  end

  def cors_origin_handler(conn) do
    case Enum.find_value(conn.req_headers, fn {k, v} -> k =~ ~r/^origin$/i && v end) do
      nil -> nil
      origin ->
        if allowed_origin?(origin) do
          origin
        else
          nil
        end
    end
  end

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

  plug(CORSPlug, origin: &RetWeb.Endpoint.cors_origin_handler/1)
  plug(RetWeb.Plugs.AddVary)
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
