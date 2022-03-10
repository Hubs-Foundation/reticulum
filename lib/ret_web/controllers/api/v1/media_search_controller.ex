defmodule RetWeb.Api.V1.MediaSearchController do
  use RetWeb, :controller
  use Retry

  def index(conn, %{"source" => "rooms"} = params) do
    {:commit, results} =
      %Ret.MediaSearchQuery{
        source: "rooms",
        cursor: params["cursor"] || "1",
        filter: params["filter"],
        q: params["q"]
      }
      |> Ret.MediaSearch.search()

    conn |> render("index.json", results: results)
  end

  def index(conn, %{"source" => "sketchfab", "user" => user}) do
    {:commit, results} = %Ret.MediaSearchQuery{source: "sketchfab", user: user} |> Ret.MediaSearch.search()
    conn |> render("index.json", results: results)
  end

  def index(conn, %{"source" => "scene_listings"} = params) do
    {:commit, results} =
      %Ret.MediaSearchQuery{
        source: "scene_listings",
        q: params["q"],
        filter: params["filter"],
        cursor: params["cursor"] || "1"
      }
      |> Ret.MediaSearch.search()

    conn |> render("index.json", results: results)
  end

  def index(conn, %{"source" => "avatar_listings"} = params) do
    {:commit, results} =
      %Ret.MediaSearchQuery{
        source: "avatar_listings",
        q: params["q"],
        filter: params["filter"],
        similar_to: params["similar_to"],
        cursor: params["cursor"] || "1"
      }
      |> Ret.MediaSearch.search()

    conn |> render("index.json", results: results)
  end

  def index(conn, %{"source" => source, "user" => user} = params)
      when source in ["scenes", "avatars", "favorites", "assets"] do
    account = conn |> Guardian.Plug.current_resource()

    if account && account.account_id == String.to_integer(user) do
      {:commit, results} =
        %Ret.MediaSearchQuery{
          source: source,
          cursor: params["cursor"] || "1",
          user: account.account_id,
          type: params["type"],
          q: params["q"]
        }
        |> Ret.MediaSearch.search()

      conn |> render("index.json", results: results)
    else
      conn |> send_resp(401, "You can only search #{source} by user for your own account.")
    end
  end

  def index(conn, %{"source" => source}) when source in ["favorites"] do
    conn |> send_resp(401, "Missing account id for favorites search.")
  end

  def index(conn, %{"source" => source} = params)
      when source in ["sketchfab", "tenor", "youtube_videos", "bing_videos", "bing_images", "twitch"] do
    query = %Ret.MediaSearchQuery{
      source: source,
      cursor: params["cursor"],
      q: params["q"],
      filter: params["filter"],
      collection: params["collection"],
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
       when source == "youtube_videos",
       do: :media_search_results_long

  defp cache_for_query(_query), do: :media_search_results

  def index(conn) do
    conn |> send_resp(422, "")
  end
end
