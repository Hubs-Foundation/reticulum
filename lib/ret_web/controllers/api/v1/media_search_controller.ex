defmodule RetWeb.Api.V1.MediaSearchController do
  use RetWeb, :controller
  use Retry

  def index(conn, %{"source" => "sketchfab", "user" => user}) do
    {:commit, results} = %Ret.MediaSearchQuery{source: "sketchfab", user: user} |> Ret.MediaSearch.search()
    conn |> render("index.json", results: results)
  end

  def index(conn, %{"source" => "scene_listings", "filter" => "featured"} = params) do
    {:commit, results} =
      %Ret.MediaSearchQuery{source: "scene_listings", cursor: params["cursor"] || "1", filter: "featured"}
      |> Ret.MediaSearch.search()

    conn |> render("index.json", results: results)
  end

  def index(conn, %{"source" => "scene_listings", "q" => q} = params) do
    {:commit, results} =
      %Ret.MediaSearchQuery{source: "scene_listings", cursor: params["cursor"] || "1", q: q} |> Ret.MediaSearch.search()

    conn |> render("index.json", results: results)
  end

  def index(conn, %{"source" => "scene_listings"} = params) do
    {:commit, results} =
      %Ret.MediaSearchQuery{source: "scene_listings", cursor: params["cursor"] || "1"} |> Ret.MediaSearch.search()

    conn |> render("index.json", results: results)
  end

  def index(conn, %{"source" => "avatar_listings", "filter" => "featured"} = params) do
    {:commit, results} =
      %Ret.MediaSearchQuery{source: "avatar_listings", cursor: params["cursor"] || "1", filter: "featured"}
      |> Ret.MediaSearch.search()

    conn |> render("index.json", results: results)
  end

  def index(conn, %{"source" => "avatar_listings", "q" => q} = params) do
    {:commit, results} =
      %Ret.MediaSearchQuery{source: "avatar_listings", cursor: params["cursor"] || "1", q: q}
      |> Ret.MediaSearch.search()

    conn |> render("index.json", results: results)
  end

  def index(conn, %{"source" => "avatar_listings"} = params) do
    {:commit, results} =
      %Ret.MediaSearchQuery{source: "avatar_listings", cursor: params["cursor"] || "1"} |> Ret.MediaSearch.search()

    conn |> render("index.json", results: results)
  end

  def index(conn, %{"source" => "avatars", "user" => user} = params) do
    account = conn |> Guardian.Plug.current_resource()

    if account && account.account_id == String.to_integer(user) do
      {:commit, results} =
        %Ret.MediaSearchQuery{source: "avatars", cursor: params["cursor"] || "1", user: account.account_id}
        |> Ret.MediaSearch.search()

      conn |> render("index.json", results: results)
    else
      conn |> send_resp(401, "You can only search avatars by user for your own account.")
    end
  end

  def index(conn, %{"source" => "scenes", "user" => user} = params) do
    account = conn |> Guardian.Plug.current_resource()

    if account && account.account_id == String.to_integer(user) do
      {:commit, results} =
        %Ret.MediaSearchQuery{source: "scenes", cursor: params["cursor"] || "1", user: account.account_id}
        |> Ret.MediaSearch.search()

      conn |> render("index.json", results: results)
    else
      conn |> send_resp(401, "You can only search scenes by user for your own account.")
    end
  end

  def index(conn, %{"source" => "assets", "user" => user} = params) do
    account = conn |> Guardian.Plug.current_resource()

    if account.account_id == String.to_integer(user) do
      {:commit, results} =
        %Ret.MediaSearchQuery{
          source: "assets",
          user: account.account_id,
          type: params["type"],
          q: params["q"],
          cursor: params["cursor"] || "1"
        }
        |> Ret.MediaSearch.search()

      conn |> render("index.json", results: results)
    else
      conn |> send_resp(401, "")
    end
  end

  def index(conn, %{"source" => source} = params)
      when source in ["sketchfab", "poly", "tenor", "youtube_videos", "bing_videos", "bing_images", "twitch"] do
    query = %Ret.MediaSearchQuery{
      source: source,
      cursor: params["cursor"],
      q: params["q"],
      filter: params["filter"],
      locale: params["locale"]
    }

    case Cachex.fetch(cache_for_query(query), query) do
      {_status, nil} ->
        conn |> send_resp(404, "")

      {_status, %Ret.MediaSearchResult{} = results} ->
        conn |> render("index.json", results: results)

      _ ->
        conn |> send_resp(404, "")
    end
  end

  # For Google services, increase cache duration for landing pages by using long-lived cache, due to quotas.
  defp cache_for_query(%Ret.MediaSearchQuery{source: source, q: nil})
       when source == "youtube_videos" or source == "poly",
       do: :media_search_results_long

  defp cache_for_query(_query), do: :media_search_results

  def index(conn) do
    conn |> send_resp(422, "")
  end
end
