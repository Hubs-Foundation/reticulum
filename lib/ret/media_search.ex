defmodule Ret.MediaSearchQuery do
  @enforce_keys [:source]
  defstruct [:source, :type, :user, :filter, :q, :cursor, :locale]
end

defmodule Ret.MediaSearchResult do
  @enforce_keys [:meta, :entries]
  defstruct [:meta, :entries, :suggestions]
end

defmodule Ret.MediaSearchResultMeta do
  @enforce_keys [:source]
  defstruct [:source, :next_cursor]
end

defmodule Ret.MediaSearch do
  require Logger

  import Ret.HttpUtils
  import Ecto.Query

  alias Ret.{Repo, OwnedFile, Scene, SceneListing, Asset, Avatar, AvatarListing, AccountHubFavorite}

  @page_size 24
  # HACK for now to reduce page size for scene listings -- real fix will be to expose page_size to API
  @scene_page_size 23
  @max_face_count 60000

  def search(%Ret.MediaSearchQuery{source: "scene_listings", cursor: cursor, filter: "featured", q: query}) do
    scene_listing_search(cursor, query, "featured", asc: :order)
  end

  def search(%Ret.MediaSearchQuery{source: "scene_listings", cursor: cursor, filter: filter, q: query}) do
    scene_listing_search(cursor, query, filter)
  end

  def search(%Ret.MediaSearchQuery{source: "scenes", cursor: cursor, filter: filter, user: account_id, q: query}) do
    scene_search(cursor, query, filter, account_id)
  end

  def search(%Ret.MediaSearchQuery{source: "avatar_listings", cursor: cursor, filter: "featured", q: query}) do
    avatar_listing_search(cursor, query, "featured", asc: :order)
  end

  def search(%Ret.MediaSearchQuery{source: "avatar_listings", cursor: cursor, filter: filter, q: query}) do
    avatar_listing_search(cursor, query, filter)
  end

  def search(%Ret.MediaSearchQuery{source: "avatars", cursor: cursor, filter: filter, user: account_id, q: query}) do
    avatar_search(cursor, query, filter, account_id)
  end

  def search(%Ret.MediaSearchQuery{source: "assets", type: type, cursor: cursor, user: account_id, q: query}) do
    assets_search(cursor, type, account_id, query)
  end

  def search(%Ret.MediaSearchQuery{source: "favorites", type: "hubs", cursor: cursor, user: account_id, q: q}) do
    favorites_search(cursor, "hubs", account_id, q)
  end

  def search(%Ret.MediaSearchQuery{source: "sketchfab", cursor: cursor, filter: "featured", q: q}) do
    query =
      URI.encode_query(
        type: :models,
        downloadable: true,
        count: @page_size,
        max_face_count: @max_face_count,
        processing_status: :succeeded,
        sort_by: "-likeCount",
        cursor: cursor,
        q: q
      )

    sketchfab_search(query)
  end

  def search(%Ret.MediaSearchQuery{source: "sketchfab", cursor: cursor, filter: filter, q: q}) do
    query =
      URI.encode_query(
        type: :models,
        downloadable: true,
        count: @page_size,
        max_face_count: @max_face_count,
        processing_status: :succeeded,
        cursor: cursor,
        categories: filter,
        sort_by:
          if q == nil || q == "" do
            "-likeCount"
          else
            nil
          end,
        q: q
      )

    sketchfab_search(query)
  end

  def search(%Ret.MediaSearchQuery{source: "poly", cursor: cursor, filter: filter, q: q}) do
    with api_key when is_binary(api_key) <- resolver_config(:google_poly_api_key) do
      query =
        URI.encode_query(
          pageSize: @page_size,
          maxComplexity: :MEDIUM,
          format: :GLTF2,
          pageToken: cursor,
          category: filter,
          keywords: q,
          key: api_key
        )

      res =
        "https://poly.googleapis.com/v1/assets?#{query}"
        |> retry_get_until_success()

      case res do
        :error ->
          :error

        res ->
          decoded_res = res |> Map.get(:body) |> Poison.decode!()
          entries = decoded_res |> Map.get("assets") |> Enum.map(&poly_api_result_to_entry/1)
          next_cursor = decoded_res |> Map.get("nextPageToken")

          {:commit,
           %Ret.MediaSearchResult{
             meta: %Ret.MediaSearchResultMeta{
               next_cursor: next_cursor,
               source: :poly
             },
             entries: entries
           }}
      end
    else
      _ -> nil
    end
  end

  def search(%Ret.MediaSearchQuery{source: "youtube_videos", cursor: cursor, filter: filter, q: q}) do
    with api_key when is_binary(api_key) <- resolver_config(:youtube_api_key) do
      query =
        URI.encode_query(
          part: :snippet,
          fields: "nextPageToken,items(id,snippet(title,channelTitle,thumbnails(medium(url))))",
          maxResults: @page_size,
          pageToken: cursor,
          order: :relevance,
          category: filter,
          q: q,
          safeSearch: :moderate,
          type: :video,
          key: api_key
        )

      Logger.info("YT Search #{q} | #{filter} | #{cursor}")

      res =
        "https://www.googleapis.com/youtube/v3/search?#{query}"
        |> retry_get_until_success()

      case res do
        :error ->
          :error

        res ->
          decoded_res = res |> Map.get(:body) |> Poison.decode!()
          entries = decoded_res |> Map.get("items") |> Enum.map(&youtube_api_result_to_entry/1)
          next_cursor = decoded_res |> Map.get("nextPageToken")

          {:commit,
           %Ret.MediaSearchResult{
             meta: %Ret.MediaSearchResultMeta{
               next_cursor: next_cursor,
               source: :youtube
             },
             entries: entries
           }}
      end
    else
      _ -> nil
    end
  end

  def search(%Ret.MediaSearchQuery{source: "tenor", cursor: cursor, filter: filter, q: q}) do
    with api_key when is_binary(api_key) <- resolver_config(:tenor_api_key) do
      query =
        URI.encode_query(
          q: q,
          contentfilter: :low,
          media_filter: :minimal,
          limit: @page_size,
          pos: cursor,
          key: api_key
        )

      res =
        if filter == "trending" do
          "https://api.tenor.com/v1/trending?#{query}"
        else
          "https://api.tenor.com/v1/search?#{query}"
        end
        |> retry_get_until_success()

      case res do
        :error ->
          :error

        res ->
          decoded_res = res |> Map.get(:body) |> Poison.decode!()
          next_cursor = decoded_res |> Map.get("next")
          entries = decoded_res |> Map.get("results") |> Enum.map(&tenor_api_result_to_entry/1)

          {:commit,
           %Ret.MediaSearchResult{
             meta: %Ret.MediaSearchResultMeta{source: :tenor, next_cursor: next_cursor},
             entries: entries
           }}
      end
    else
      _ -> nil
    end
  end

  def search(%Ret.MediaSearchQuery{source: "bing_videos"} = query) do
    bing_search(query)
  end

  def search(%Ret.MediaSearchQuery{source: "bing_images"} = query) do
    bing_search(query)
  end

  def search(%Ret.MediaSearchQuery{source: "twitch", cursor: cursor, filter: _filter, q: q}) do
    with client_id when is_binary(client_id) <- resolver_config(:twitch_client_id) do
      query =
        URI.encode_query(
          query: q,
          limit: @page_size,
          offset: cursor || 0
        )

      res =
        "https://api.twitch.tv/kraken/search/streams?#{query}" |> retry_get_until_success([{"Client-ID", client_id}])

      case res do
        :error ->
          :error

        res ->
          decoded_res = res |> Map.get(:body) |> Poison.decode!()
          next_uri = decoded_res |> Map.get("_links") |> Map.get("next") |> URI.parse()
          next_cursor = next_uri.query |> URI.decode_query() |> Map.get("offset")

          entries = decoded_res |> Map.get("streams") |> Enum.map(&twitch_api_result_to_entry/1)

          {:commit,
           %Ret.MediaSearchResult{
             meta: %Ret.MediaSearchResultMeta{source: :twitch, next_cursor: next_cursor},
             entries: entries
           }}
      end
    else
      _ -> nil
    end
  end

  defp sketchfab_search(query) do
    with api_key when is_binary(api_key) <- resolver_config(:sketchfab_api_key) do
      res =
        "https://api.sketchfab.com/v3/search?#{query}"
        |> retry_get_until_success([{"Authorization", "Token #{api_key}"}])

      case res do
        :error ->
          :error

        res ->
          decoded_res = res |> Map.get(:body) |> Poison.decode!()
          entries = decoded_res |> Map.get("results") |> Enum.map(&sketchfab_api_result_to_entry/1)
          cursors = decoded_res |> Map.get("cursors")

          {:commit,
           %Ret.MediaSearchResult{
             meta: %Ret.MediaSearchResultMeta{next_cursor: cursors["next"], source: :sketchfab},
             entries: entries
           }}
      end
    else
      _ -> nil
    end
  end

  def bing_search(%Ret.MediaSearchQuery{source: "bing_videos", q: q, locale: locale}) when q == nil or q == "" do
    with api_key when is_binary(api_key) <- resolver_config(:bing_search_api_key) do
      query =
        URI.encode_query(
          mkt: locale || "en-US",
          safeSearch: :Strict
        )

      res =
        "https://westus.api.cognitive.microsoft.com/bing/v7.0/videos/trending?#{query}"
        |> retry_get_until_success([{"Ocp-Apim-Subscription-Key", api_key}])

      case res do
        :error ->
          :error

        res ->
          decoded_res = res |> Map.get(:body) |> Poison.decode!()

          tiles =
            decoded_res
            |> Kernel.get_in(["categories"])
            |> Kernel.get_in([Access.all(), "subcategories"])
            |> List.flatten()
            |> Enum.map(&Kernel.get_in(&1, ["tiles"]))
            |> List.flatten()

          entries = tiles |> Enum.shuffle() |> Enum.with_index() |> Enum.map(&bing_trending_api_result_to_entry/1)

          {:commit,
           %Ret.MediaSearchResult{
             meta: %Ret.MediaSearchResultMeta{source: "bing_videos", next_cursor: nil},
             entries: entries,
             suggestions: []
           }}
      end
    else
      _ -> nil
    end
  end

  def bing_search(%Ret.MediaSearchQuery{source: source, cursor: cursor, filter: _filter, q: q, locale: locale}) do
    with api_key when is_binary(api_key) <- resolver_config(:bing_search_api_key) do
      query =
        URI.encode_query(
          count: @page_size,
          offset: cursor || 0,
          mkt: locale || "en-US",
          q: q,
          safeSearch: :Strict,
          pricing: :Free
        )

      type = source |> String.replace("bing_", "")

      res =
        "https://westus.api.cognitive.microsoft.com/bing/v7.0/#{type}/search?#{query}"
        |> retry_get_until_success([{"Ocp-Apim-Subscription-Key", api_key}])

      case res do
        :error ->
          :error

        res ->
          decoded_res = res |> Map.get(:body) |> Poison.decode!()
          next_cursor = decoded_res |> Map.get("nextOffset")
          entries = decoded_res |> Map.get("value") |> Enum.map(&bing_api_result_to_entry(type, &1))

          suggestions =
            if decoded_res["relatedSearches"] do
              decoded_res |> Map.get("relatedSearches") |> Enum.map(& &1["text"])
            else
              []
            end

          {:commit,
           %Ret.MediaSearchResult{
             meta: %Ret.MediaSearchResultMeta{source: source, next_cursor: next_cursor},
             entries: entries,
             suggestions: suggestions
           }}
      end
    else
      _ -> nil
    end
  end

  defp assets_search(cursor, type, account_id, query, order \\ [desc: :updated_at]) do
    page_number = (cursor || "1") |> Integer.parse() |> elem(0)

    results =
      Asset
      |> where([a], a.account_id == ^account_id)
      |> add_type_to_asset_search_query(type)
      |> add_query_to_asset_search_query(query)
      |> preload([:asset_owned_file, :thumbnail_owned_file])
      |> order_by(^order)
      |> Repo.paginate(%{page: page_number, page_size: @page_size})
      |> result_for_assets_page(page_number)

    {:commit, results}
  end

  defp favorites_search(cursor, "hubs", account_id, _query, order \\ [desc: :last_joined_at]) do
    page_number = (cursor || "1") |> Integer.parse() |> elem(0)

    results =
      AccountHubFavorite
      |> where([a], a.account_id == ^account_id)
      |> preload(hub: [scene: [:screenshot_owned_file], scene_listing: [:screenshot_owned_file]])
      |> order_by(^order)
      |> Repo.paginate(%{page: page_number, page_size: @page_size})
      |> result_for_page(page_number, :scenes, &hub_favorite_to_entry/1)

    {:commit, results}
  end

  defp add_type_to_asset_search_query(query, nil), do: query
  defp add_type_to_asset_search_query(query, type), do: query |> where([a], a.type == ^type)
  defp add_query_to_asset_search_query(query, nil), do: query
  defp add_query_to_asset_search_query(query, q), do: query |> where([a], ilike(a.name, ^"%#{q}%"))

  defp result_for_assets_page(page, page_number) do
    %Ret.MediaSearchResult{
      meta: %Ret.MediaSearchResultMeta{
        next_cursor:
          if page.total_pages > page_number do
            page_number + 1
          else
            nil
          end,
        source: :assets
      },
      entries:
        page.entries
        |> Enum.map(&asset_to_entry/1)
    }
  end

  defp asset_to_entry(asset) do
    %{
      id: asset.asset_sid,
      url: asset.asset_owned_file |> OwnedFile.uri_for() |> URI.to_string(),
      type: asset.type,
      name: asset.name,
      attributions: %{},
      images: %{
        preview: %{url: asset.thumbnail_owned_file |> OwnedFile.uri_for() |> URI.to_string()}
      }
    }
  end

  defp avatar_search(cursor, _query, _filter, account_id, order \\ [desc: :updated_at]) do
    page_number = (cursor || "1") |> Integer.parse() |> elem(0)

    results =
      Avatar
      |> where([a], a.account_id == ^account_id)
      |> preload([:thumbnail_owned_file])
      |> order_by(^order)
      |> Repo.paginate(%{page: page_number, page_size: @page_size})
      |> result_for_page(page_number, :avatar, &avatar_to_entry/1)

    {:commit, results}
  end

  defp avatar_listing_search(cursor, query, filter, order \\ [desc: :updated_at]) do
    page_number = (cursor || "1") |> Integer.parse() |> elem(0)

    results =
      AvatarListing
      |> join(:inner, [l], a in assoc(l, :avatar))
      |> where([l, a], l.state == ^"active" and a.state == ^"active" and a.allow_promotion == ^true)
      |> add_query_to_listing_search_query(query)
      |> add_tag_to_listing_search_query(filter)
      |> preload([:thumbnail_owned_file])
      |> order_by(^order)
      |> Repo.paginate(%{page: page_number, page_size: @page_size})
      |> result_for_page(page_number, :avatar_listings, &avatar_listing_to_entry/1)

    {:commit, results}
  end

  defp scene_listing_search(cursor, query, filter, order \\ [desc: :updated_at]) do
    page_number = (cursor || "1") |> Integer.parse() |> elem(0)

    results =
      SceneListing
      |> join(:inner, [l], s in assoc(l, :scene))
      |> where([l, s], l.state == ^"active" and s.state == ^"active" and s.allow_promotion == ^true)
      |> add_query_to_listing_search_query(query)
      |> add_tag_to_listing_search_query(filter)
      |> preload([:screenshot_owned_file, :model_owned_file, :scene_owned_file])
      |> order_by(^order)
      |> Repo.paginate(%{page: page_number, page_size: @scene_page_size})
      |> result_for_page(page_number, :scene_listings, &scene_or_scene_listing_to_entry/1)

    {:commit, results}
  end

  defp scene_search(cursor, _query, _filter, account_id, order \\ [desc: :updated_at]) do
    page_number = (cursor || "1") |> Integer.parse() |> elem(0)

    results =
      Scene
      |> where([a], a.account_id == ^account_id)
      |> preload([:screenshot_owned_file, :model_owned_file, :scene_owned_file])
      |> order_by(^order)
      |> Repo.paginate(%{page: page_number, page_size: @scene_page_size})
      |> result_for_page(page_number, :scenes, &scene_or_scene_listing_to_entry/1)

    {:commit, results}
  end

  defp add_query_to_listing_search_query(query, nil), do: query
  defp add_query_to_listing_search_query(query, q), do: query |> where([l, s], ilike(l.name, ^"%#{q}%"))

  defp add_tag_to_listing_search_query(query, nil), do: query
  defp add_tag_to_listing_search_query(query, tag), do: query |> where(fragment("tags->'tags' \\? ?", ^tag))

  defp result_for_page(page, page_number, source, entry_fn) do
    %Ret.MediaSearchResult{
      meta: %Ret.MediaSearchResultMeta{
        next_cursor:
          if page.total_pages > page_number do
            page_number + 1
          else
            nil
          end,
        source: source
      },
      entries:
        page.entries
        |> Enum.map(entry_fn)
    }
  end

  defp hub_favorite_to_entry(%AccountHubFavorite{hub: hub} = favorite) do
    scene_entry = scene_or_scene_listing_to_entry(hub.scene || hub.scene_listing, "scene")

    %{
      id: hub.hub_sid,
      name: hub.name,
      last_joined_at: favorite.last_joined_at,
      images: scene_entry.images
    }
  end

  defp scene_or_scene_listing_to_entry(%Scene{} = scene), do: scene_or_scene_listing_to_entry(scene, "scene")

  defp scene_or_scene_listing_to_entry(%SceneListing{} = scene),
    do: scene_or_scene_listing_to_entry(scene, "scene_listing")

  defp scene_or_scene_listing_to_entry(s, type) do
    %{
      id: s |> Scene.to_sid(),
      url: s |> Scene.to_url(),
      type: type,
      name: s.name,
      description: s.description,
      attributions: s.attributions,
      images: %{
        preview: %{url: s.screenshot_owned_file |> OwnedFile.uri_for() |> URI.to_string()}
      }
    }
  end

  defp avatar_to_entry(avatar) do
    thumbnail = avatar |> Avatar.file_url_or_nil(:thumbnail_owned_file)

    %{
      id: avatar.avatar_sid,
      type: "avatar",
      url: avatar |> Avatar.url(),
      name: avatar.name,
      description: avatar.description,
      attributions: avatar.attributions,
      images: %{
        preview: %{
          url: thumbnail || "https://asset-bundles-prod.reticulum.io/bots/avatar_unavailable.png",
          width: 720,
          height: 1280
        }
      },
      gltfs: %{
        avatar: avatar |> Avatar.gltf_url(),
        base: avatar |> Avatar.base_gltf_url()
      }
    }
  end

  defp avatar_listing_to_entry(avatar_listing) do
    thumbnail = avatar_listing |> Avatar.file_url_or_nil(:thumbnail_owned_file)

    %{
      id: avatar_listing.avatar_listing_sid,
      type: "avatar_listing",
      url: avatar_listing |> Avatar.url(),
      name: avatar_listing.name,
      description: avatar_listing.description,
      attributions: avatar_listing.attributions,
      images: %{
        preview: %{
          url: thumbnail || "https://asset-bundles-prod.reticulum.io/bots/avatar_unavailable.png",
          width: 720,
          height: 1280
        }
      },
      gltfs: %{
        avatar: avatar_listing |> Avatar.gltf_url(),
        base: avatar_listing |> Avatar.base_gltf_url()
      }
    }
  end

  defp sketchfab_api_result_to_entry(%{"thumbnails" => thumbnails} = result) do
    images = %{
      preview: %{
        url:
          thumbnails["images"]
          |> Enum.sort_by(fn x -> -x["size"] end)
          |> Enum.at(0)
          |> Kernel.get_in(["url"])
      }
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

  defp poly_api_result_to_entry(result) do
    %{
      id: result["name"],
      type: "poly_model",
      name: result["displayName"],
      attributions: %{creator: %{name: result["authorName"]}},
      url: "https://poly.google.com/view/#{result["name"] |> String.replace("assets/", "")}",
      images: %{preview: %{url: result["thumbnail"]["url"]}}
    }
  end

  defp youtube_api_result_to_entry(result) do
    %{
      id: result["id"]["videoId"],
      type: "youtube_video",
      name: result["snippet"]["title"],
      attributions: %{creator: %{name: result["snippet"]["channelTitle"]}},
      url: "https://www.youtube.com/watch?v=#{result["id"]["videoId"]}",
      images: %{preview: %{url: result["snippet"]["thumbnails"]["medium"]["url"]}}
    }
  end

  defp tenor_api_result_to_entry(result) do
    media_entry = result["media"] |> Enum.at(0)

    %{
      id: result["id"],
      type: "tenor_image",
      name: result["title"],
      attributions: %{},
      url: media_entry["mp4"]["url"],
      images: %{
        preview: %{
          url: media_entry["tinygif"]["url"],
          width: media_entry["tinygif"]["dims"] |> Enum.at(0),
          height: media_entry["tinygif"]["dims"] |> Enum.at(1)
        }
      }
    }
  end

  defp bing_api_result_to_entry(type, result) do
    object_type = type |> String.replace(~r/s$/, "")

    attributions = %{}

    attributions =
      if result["publisher"] do
        attributions |> Map.put(:publisher, result["publisher"] |> Enum.at(0))
      else
        attributions
      end

    attributions =
      if result["creator"] do
        attributions |> Map.put(:creator, result["creator"])
      else
        attributions
      end

    %{
      id: result["#{object_type}Id"],
      type: "bing_#{object_type}",
      name: result["name"],
      attributions: attributions,
      url: result["contentUrl"],
      images: %{
        preview: %{
          url: result["thumbnailUrl"],
          width: result["thumbnail"]["width"],
          height: result["thumbnail"]["height"]
        }
      }
    }
  end

  defp bing_trending_api_result_to_entry({result, index}) do
    search_url = result["query"]["webSearchUrl"] |> URI.parse()
    search_query = search_url.query |> URI.decode_query()

    %{
      id: index,
      type: "bing_video",
      name: result["query"]["displayText"],
      url: result["image"]["contentUrl"],
      lucky_query: search_query["q"],
      images: %{
        preview: %{
          url: result["image"]["thumbnailUrl"],
          width: 474,
          height: 248
        }
      }
    }
  end

  defp twitch_api_result_to_entry(result) do
    %{
      id: result["_id"],
      type: "twitch_stream",
      name: result["channel"]["status"],
      attributions: %{
        game: %{name: result["game"]},
        creator: %{name: result["channel"]["name"], url: result["channel"]["url"]}
      },
      url: result["channel"]["url"],
      images: %{preview: %{url: result["preview"]["large"]}}
    }
  end

  defp resolver_config(key) do
    Application.get_env(:ret, Ret.MediaResolver)[key]
  end
end
