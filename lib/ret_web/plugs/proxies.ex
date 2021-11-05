defmodule RetWeb.Plugs.PostgrestProxy do
  use Plug.Builder
  pgrest_host = Application.get_env(:ret, :pgrest_host) || "localhost:3000"
  plug ReverseProxyPlug, upstream: "http://#{pgrest_host}"
end

defmodule RetWeb.Plugs.ItaProxy do
  use Plug.Builder
  ita_host = Application.get_env(:ret, :ita_host) || "localhost:6000"
  plug ReverseProxyPlug, upstream: "http://#{ita_host}"
end
