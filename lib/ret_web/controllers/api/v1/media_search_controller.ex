defmodule RetWeb.Api.V1.MediaSearchController do
  use RetWeb, :controller
  use Retry

  def index(conn, %{"api" => api, "user" => user}) when api in ["sketchfab"] do
    query = %Ret.MediaSearchQuery{api: api, user: user}
    results = Ret.MediaSearch.search(query)
    conn |> render("index.json", results: results)
  end

  def index(conn) do
    conn |> send_resp(422, "")
  end
end
