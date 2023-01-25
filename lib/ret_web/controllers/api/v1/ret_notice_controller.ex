defmodule RetWeb.Api.V1.RetNoticeController do
  use RetWeb, :controller

  # Limit to 1 TPS
  plug RetWeb.Plugs.RateLimit

  # Only allow access to send ret notifications via admin secret
  plug RetWeb.Plugs.HeaderAuthorization when action in [:create]

  def create(conn, payload) do
    RetWeb.Endpoint.broadcast("ret", "notice", payload)
    conn |> send_resp(200, "")
  end
end
