defmodule Ret.MediaSearchQuery do
  @enforce_keys [:source]
  defstruct [:source, :user, :filter, :q, :cursor, page: 1]
end

defmodule Ret.MediaSearchResult do
  @enforce_keys [:meta, :entries]
  defstruct [:meta, :entries]
end

defmodule Ret.MediaSearchResultMeta do
  @enforce_keys [:source]
  defstruct [:source, :page, :page_size, :total_pages, :total_entries, :next_cursor, :previous_cursor]
end

defmodule Ret.MediaSearch do
  import Ret.HttpUtils
  import Ecto.Query

  alias Ret.{Repo, OwnedFile, Scene, SceneListing}

  @page_size 24
  @max_face_count 60000

  def search(%Ret.MediaSearchQuery{source: "scene_listings", page: page, filter: "featured", q: query}) do
    scene_listing_search(page, query, "featured", asc: :order)
  end

  def search(%Ret.MediaSearchQuery{source: "scene_listings", page: page, filter: filter, q: query}) do
    scene_listing_search(page, query, filter)
  end

  def search(%Ret.MediaSearchQuery{source: "sketchfab", cursor: cursor, filter: filter, q: query}) do
    with api_key when is_binary(api_key) <- resolver_config(:sketchfab_api_key) do
      query =
        URI.encode_query(
          type: :models,
          downloadable: true,
          count: @page_size,
          face_count: @max_face_count,
          processing_status: :succeeded,
          cursor: cursor,
          categories: filter,
          q: query
        )

      res =
        "https://api.sketchfab.com/v3/search?#{query}"
        |> retry_get_until_success([{"Authorization", "Token #{api_key}"}])

      case res do
        :error ->
          :error

        res ->
          decoded_res =
            res
            |> Map.get(:body)
            |> Poison.decode!()

          entries = decoded_res |> Map.get("results") |> Enum.map(&sketchfab_api_result_to_entry/1)
          cursors = decoded_res |> Map.get("cursors")

          result = %Ret.MediaSearchResult{
            meta: %Ret.MediaSearchResultMeta{
              next_cursor: cursors["next"],
              previous_cursor: cursors["previous"],
              source: :sketchfab
            },
            entries: entries
          }

          { :commit, result }
      end
    else
      _ -> nil
    end
  end

  defp scene_listing_search(page, query, filter, order \\ [desc: :updated_at]) do
    results = SceneListing
    |> join(:inner, [l], s in assoc(l, :scene))
    |> where([l, s], l.state == ^"active" and s.state == ^"active" and s.allow_promotion == ^true)
    |> add_query_to_listing_search_query(query)
    |> add_tag_to_listing_search_query(filter)
    |> preload([:screenshot_owned_file, :model_owned_file, :scene_owned_file])
    |> order_by(^order)
    |> Repo.paginate(%{page: page, page_size: @page_size})
    |> result_for_scene_listing_page()

    { :commit, results }
  end

  defp add_query_to_listing_search_query(query, nil), do: query
  defp add_query_to_listing_search_query(query, q), do: query |> where([l, s], ilike(l.name, ^"%#{q}%"))

  defp add_tag_to_listing_search_query(query, nil), do: query
  defp add_tag_to_listing_search_query(query, tag), do: query |> where(fragment("tags->'tags' \\? ?", ^tag))

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
      url: scene_listing |> Scene.to_url(),
      type: "scene_listing",
      name: scene_listing.name,
      description: scene_listing.description,
      attributions: scene_listing.attributions,
      images: %{
        preview: scene_listing.screenshot_owned_file |> OwnedFile.uri_for() |> URI.to_string()
      }
    }
  end

  defp sketchfab_api_result_to_entry(%{"thumbnails" => thumbnails} = result) do
    images = %{
      preview:
        thumbnails["images"]
        |> Enum.sort_by(fn x -> -x["size"] end)
        |> Enum.at(0)
        |> Kernel.get_in(["url"])
    }

    sketchfab_api_result_to_entry(result, images)
  end

  defp sketchfab_api_result_to_entry(result) do
    sketchfab_api_result_to_entry(result, %{})
  end

  defp sketchfab_api_result_to_entry(result, images) do
    %{
      id: result["uid"],
      type: "sketchfab_model",
      name: result["name"],
      attributions: %{creator: %{name: result["user"]["username"], url: result["user"]["profileUrl"]}},
      url: "https://sketchfab.com/models/#{result["uid"]}",
      images: images
    }
  end

  defp resolver_config(key) do
    Application.get_env(:ret, Ret.MediaResolver)[key]
  end
end
