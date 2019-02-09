defmodule RetWeb.Api.V1.MediaSearchController do
  use RetWeb, :controller
  use Retry

  def index(conn, %{"source" => "sketchfab", "user" => user}) do
    results = %Ret.MediaSearchQuery{source: "sketchfab", user: user} |> Ret.MediaSearch.search()
    conn |> render("index.json", results: results)
  end

  def index(conn, %{"source" => "scene_listings", "filter" => "featured"} = params) do
    page = params["page"] || 1

    results =
      %Ret.MediaSearchQuery{source: "scene_listings", page: page, filter: "featured"} |> Ret.MediaSearch.search()

    conn |> render("index.json", results: results)
  end

  def index(conn, %{"source" => "scene_listings", "q" => q} = params) do
    page = params["page"] || 1
    results = %Ret.MediaSearchQuery{source: "scene_listings", page: page, q: q} |> Ret.MediaSearch.search()

    conn |> render("index.json", results: results)
  end

  def index(conn, %{"source" => "scene_listings"} = params) do
    page = params["page"] || 1
    results = %Ret.MediaSearchQuery{source: "scene_listings", page: page} |> Ret.MediaSearch.search()

    conn |> render("index.json", results: results)
  end

  def index(conn, %{"source" => "sketchfab"} = params) do
    IO.puts("IN")

    results =
      %Ret.MediaSearchQuery{
        source: "sketchfab",
        cursor: params["cursor"],
        q: params["q"],
        filter: params["filter"]
      }
      |> Ret.MediaSearch.search()

    conn |> render("index.json", results: results)
  end

  def index(conn) do
    conn |> send_resp(422, "")
  end
end
