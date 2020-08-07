defmodule RetWeb.Plugs.PostgrestProxy do
  @moduledoc false
  use Plug.Builder
  plug ReverseProxyPlug, upstream: "http://localhost:3000"
end

defmodule RetWeb.Plugs.ItaProxy do
  @moduledoc false
  use Plug.Builder
  plug ReverseProxyPlug, upstream: "http://localhost:6000"
end
