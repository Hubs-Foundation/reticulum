defmodule RetWeb.Plugs.RedirectToMainDomain do
  import Plug.Conn

  def init(options), do: options

  def call(conn, _options) do
    main_host = RetWeb.Endpoint.config(:url)[:host]
    main_scheme = RetWeb.Endpoint.config(:url)[:scheme]

    if !Regex.match?(~r/\A#{conn.host}\z/i, main_host) do
      conn
      |> put_status(:moved_permanently)
      |> Phoenix.Controller.redirect(external: "https://#{main_host}")
      |> halt()
    else
      conn
    end
  end
end
