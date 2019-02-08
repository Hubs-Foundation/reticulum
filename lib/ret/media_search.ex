defmodule Ret.MediaSearchQuery do
  @enforce_keys [:source]
  defstruct [:source, :user, :filter, :q, page: 1]
end

defmodule Ret.MediaSearchResult do
  @enforce_keys [:meta, :entries]
  defstruct [:meta, :entries]
end

defmodule Ret.MediaSearchResultMeta do
  @enforce_keys [:source, :page, :page_size, :total_pages, :total_entries]
  defstruct [:source, :page, :page_size, :total_pages, :total_entries]
end

defmodule Ret.MediaSearch do
  import Ret.HttpUtils
  import Ecto.Query

  alias Ret.{Repo, OwnedFile, SceneListing}

  @page_size 24

  def search(%Ret.MediaSearchQuery{source: "scene_listings", page: page, filter: "featured", q: query}) do
    scene_listing_search(page, query, "featured", asc: :order)
  end

  def search(%Ret.MediaSearchQuery{source: "scene_listings", page: page, filter: filter, q: query}) do
    scene_listing_search(page, query, filter)
  end

  def search(%Ret.MediaSearchQuery{source: "sketchfab", user: user}) do
    with api_key when is_binary(api_key) <- resolver_config(:sketchfab_api_key) do
      res =
        "https://api.sketchfab.com/v3/search?type=models&downloadable=true&user=#{user}"
        |> retry_get_until_success([{"Authorization", "Token #{api_key}"}])

      case res do
        :error ->
          :error

        res ->
          res
          |> Map.get(:body)
          |> Poison.decode!()
          |> Map.get("results")
          |> Enum.map(&sketchfab_api_result_to_entry/1)
      end
    else
      _ -> %{}
    end
  end

  defp scene_listing_search(page, query, filter, order \\ [desc: :updated_at]) do
    SceneListing
    |> join(:inner, [l], s in assoc(l, :scene))
    |> where([l, s], l.state == ^"active" and s.state == ^"active" and s.allow_promotion == ^true)
    |> add_query_to_listing_search_query(query)
    |> add_tag_to_listing_search_query(filter)
    |> preload([:screenshot_owned_file, :model_owned_file, :scene_owned_file])
    |> order_by(^order)
    |> Repo.paginate(%{page: page, page_size: @page_size})
    |> result_for_scene_listing_page()
  end

  def add_query_to_listing_search_query(query, nil), do: query
  def add_query_to_listing_search_query(query, q), do: query |> where([l, s], ilike(l.name, ^"%#{q}%"))

  def add_tag_to_listing_search_query(query, nil), do: query
  def add_tag_to_listing_search_query(query, tag), do: query |> where(fragment("tags->'tags' \\? ?", ^tag))

  defp result_for_scene_listing_page(page) do
    %Ret.MediaSearchResult{
      meta: %Ret.MediaSearchResultMeta{
        page: page.page_number,
        page_size: page.page_size,
        total_pages: page.total_pages,
        total_entries: page.total_entries,
        source: :scene_listings
      },
      entries:
        page.entries
        |> Enum.map(&scene_listing_to_entry/1)
    }
  end

  defp scene_listing_to_entry(scene_listing) do
    %{
      id: scene_listing.scene_listing_sid,
      url: "#{RetWeb.Endpoint.url()}/scenes/#{scene_listing.scene_listing_sid}/#{scene_listing.slug}",
      type: "scene_listing",
      name: scene_listing.name,
      description: scene_listing.description,
      attributions: scene_listing.attributions,
      images: %{
        preview: scene_listing.screenshot_owned_file |> OwnedFile.uri_for() |> URI.to_string()
      }
    }
  end

  defp sketchfab_api_result_to_entry(result) do
    # TODO when missing thumbnails
    %{
      media_url: "https://sketchfab.com/models/#{result["uid"]}",
      images: %{
        preview:
          result["thumbnails"]["images"]
          |> Enum.sort_by(fn x -> -x["size"] end)
          |> Enum.at(0)
          |> Kernel.get_in(["url"])
      }
    }
  end

  defp resolver_config(key) do
    Application.get_env(:ret, Ret.MediaResolver)[key]
  end
end
