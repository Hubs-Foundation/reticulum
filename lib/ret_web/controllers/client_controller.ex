defmodule RetWeb.ClientController do
  use RetWeb, :controller

  def index(conn, _params) do
    redirect conn, to: static_path(conn, "/client/index.html")
  end
end
