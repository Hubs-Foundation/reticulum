defmodule RetWeb.Plugs.RedirectToMainDomain do
  import Plug.Conn

  def init(options), do: options

  def call(conn, _options) do
    main_host = RetWeb.Endpoint.config(:url)[:host]
    cors_proxy_host = RetWeb.Endpoint.config(:cors_proxy_url)[:host]

    if !matches_host(conn, main_host) && !matches_host(conn, cors_proxy_host) do
      conn
      |> put_status(:moved_permanently)
      |> Phoenix.Controller.redirect(external: "https://#{main_host}")
      |> halt()
    else
      conn
    end
  end

  defp matches_host(conn, host), do: Regex.match?(~r/\A#{conn.host}\z/i, host)
end
