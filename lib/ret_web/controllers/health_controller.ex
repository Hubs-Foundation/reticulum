defmodule RetWeb.HealthController do
  use RetWeb, :controller

  def index(conn, _params) do
    send_resp(conn, 200, "ok")
  end
end
