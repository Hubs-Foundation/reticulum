defmodule RetWeb.Api.V1.MediaSearchController do
  use RetWeb, :controller
  use Retry

  def index(conn, %{"source" => "sketchfab", "user" => user}) do
    results = %Ret.MediaSearchQuery{source: "sketchfab", user: user} |> Ret.MediaSearch.search()
    conn |> render("index.json", results: results)
  end

  def index(conn, %{"source" => "pending_scenes"} = params) do
    # TODO gate on admins
    page = params["page"] || 1

    results = %Ret.MediaSearchQuery{source: "pending_scenes", page: page} |> Ret.MediaSearch.search()
    conn |> render("index.json", results: results)
  end

  def index(conn) do
    conn |> send_resp(422, "")
  end
end
