defmodule RetWeb.Api.V1.MediaSearchController do
  use RetWeb, :controller
  use Retry

  def index(conn, %{"source" => "sketchfab", "user" => user}) do
    {:commit, results} = %Ret.MediaSearchQuery{source: "sketchfab", user: user} |> Ret.MediaSearch.search()
    conn |> render("index.json", results: results)
  end

  def index(conn, %{"source" => "scene_listings", "filter" => "featured"} = params) do
    {:commit, results} =
      %Ret.MediaSearchQuery{source: "scene_listings", cursor: params["cursor"] || 1, filter: "featured"}
      |> Ret.MediaSearch.search()

    conn |> render("index.json", results: results)
  end

  def index(conn, %{"source" => "scene_listings", "q" => q} = params) do
    {:commit, results} =
      %Ret.MediaSearchQuery{source: "scene_listings", cursor: params["cursor"] || 1, q: q} |> Ret.MediaSearch.search()

    conn |> render("index.json", results: results)
  end

  def index(conn, %{"source" => "scene_listings"} = params) do
    {:commit, results} =
      %Ret.MediaSearchQuery{source: "scene_listings", cursor: params["cursor"] || 1} |> Ret.MediaSearch.search()

    conn |> render("index.json", results: results)
  end

  def index(conn, %{"source" => "assets", "user" => user} = params) do 
    account = conn |> Guardian.Plug.current_resource()

    if account.account_id == String.to_integer(user) do
      user_assets_index(conn, account, params)
    else
      conn |> send_resp(401, "")
    end
  end

  def index(conn, %{"source" => source} = params)
      when source in ["sketchfab", "poly", "tenor", "bing_videos", "bing_images", "twitch"] do
    query = %Ret.MediaSearchQuery{
      source: source,
      cursor: params["cursor"],
      q: params["q"],
      filter: params["filter"],
      locale: params["locale"]
    }

    case Cachex.fetch(:media_search_results, query) do
      {_status, nil} ->
        conn |> send_resp(404, "")

      {_status, %Ret.MediaSearchResult{} = results} ->
        conn |> render("index.json", results: results)

      _ ->
        conn |> send_resp(404, "")
    end
  end

  def index(conn) do
    conn |> send_resp(422, "")
  end

  defp user_assets_index(conn, account, %{"source" => "assets"} = params) do
    {:commit, results} =
      %Ret.MediaSearchQuery{source: "assets", user: account.account_id, type: "all", cursor: params["cursor"] || 1} |> Ret.MediaSearch.search()

    conn |> render("index.json", results: results)
  end

  defp user_assets_index(conn, account, %{"source" => "assets", "type" => "video"} = params) do
    {:commit, results} =
      %Ret.MediaSearchQuery{source: "assets", user: account.account_id, type: "videos", cursor: params["cursor"] || 1} |> Ret.MediaSearch.search()

    conn |> render("index.json", results: results)
  end

  defp user_assets_index(conn, account, %{"source" => "assets", "type" => "image"} = params) do
    {:commit, results} =
      %Ret.MediaSearchQuery{source: "assets", user: account.account_id, type: "images", cursor: params["cursor"] || 1} |> Ret.MediaSearch.search()

    conn |> render("index.json", results: results)
  end

  defp user_assets_index(conn, account, %{"source" => "assets", "type" => "model"} = params) do
    {:commit, results} =
      %Ret.MediaSearchQuery{source: "assets", user: account.account_id, type: "models", cursor: params["cursor"] || 1} |> Ret.MediaSearch.search()

    conn |> render("index.json", results: results)
  end
end
