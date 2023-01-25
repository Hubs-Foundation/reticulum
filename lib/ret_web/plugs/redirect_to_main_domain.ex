defmodule RetWeb.Plugs.RedirectToMainDomain do
  import Plug.Conn
  import Ret.ConnUtils

  def init(options), do: options

  def call(conn, _options) do
    main_host = RetWeb.Endpoint.config(:url)[:host]
    secondary_host = RetWeb.Endpoint.config(:secondary_url)[:host]
    cors_proxy_host = RetWeb.Endpoint.config(:cors_proxy_url)[:host]
    assets_host = RetWeb.Endpoint.config(:assets_url)[:host]
    link_host = RetWeb.Endpoint.config(:link_url)[:host]

    # 'host' is a misnomer
    storage_url = Application.get_env(:ret, Ret.Storage)[:host]

    storage_host =
      if storage_url do
        storage_url |> URI.parse() |> Map.get(:host)
      else
        nil
      end

    if !matches_host(conn, main_host) &&
         !matches_host(conn, secondary_host) &&
         !matches_host(conn, cors_proxy_host) &&
         !matches_host(conn, assets_host) &&
         !matches_host(conn, link_host) &&
         (!storage_host || !matches_host(conn, storage_host)) do
      conn
      |> put_status(:moved_permanently)
      |> Phoenix.Controller.redirect(external: "https://#{main_host}")
      |> halt()
    else
      conn
    end
  end
end
