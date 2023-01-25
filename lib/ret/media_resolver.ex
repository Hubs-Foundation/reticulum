defmodule Ret.ResolvedMedia do
  @enforce_keys [:uri]
  defstruct [:uri, :audio_uri, :meta, :ttl]
end

defmodule Ret.MediaResolverQuery do
  @enforce_keys [:url]
  defstruct [:url, supports_webm: true, quality: :high, version: 1]
end

defmodule Ret.MediaResolver do
  use Retry
  import Ret.HttpUtils

  require Logger

  alias Ret.{CachedFile, MediaResolverQuery, Statix, HttpUtils}

  @ytdl_valid_status_codes [200, 500]

  @youtube_rate_limit %{scale: 8_000, limit: 1}
  @sketchfab_rate_limit %{scale: 60_000, limit: 15}
  @max_await_for_rate_limit_s 120

  @non_video_root_hosts [
    "sketchfab.com",
    "giphy.com",
    "tenor.com"
  ]

  @deviant_id_regex ~r/\"DeviantArt:\/\/deviation\/([^"]+)/

  def resolve(%MediaResolverQuery{url: url} = query) when is_binary(url) do
    uri = url |> URI.parse()
    root_host = get_root_host(uri.host)
    query = Map.put(query, :url, uri)

    # TODO: We could end up running maybe_fallback_to_screenshot_opengraph_or_nothing
    #       twice in a row. These resolve functions can be simplified so that we can
    #       more easily track individual failures and only fallback when necessary.
    #       Also make sure they have a uniform response shape for indicating an
    #       error.
    case resolve(query, root_host) do
      :forbidden ->
        :forbidden

      :error ->
        maybe_fallback_to_screenshot_opengraph_or_nothing(query)

      {:error, _reason} ->
        maybe_fallback_to_screenshot_opengraph_or_nothing(query)

      {:commit, nil} ->
        maybe_fallback_to_screenshot_opengraph_or_nothing(query)

      commit ->
        commit
    end
  end

  def resolve(%MediaResolverQuery{url: %URI{host: nil}}, _root_host) do
    {:commit, nil}
  end

  # auto convert dropbox urls to "raw" urls
  def resolve(
        %MediaResolverQuery{url: %URI{host: "www.dropbox.com", path: "/s/" <> _rest} = url},
        _root_host
      ) do
    {:commit,
     url
     |> Map.put(
       :query,
       URI.decode_query(url.query)
       |> Map.delete("dl")
       |> Map.put("raw", 1)
       |> URI.encode_query()
     )
     |> resolved()}
  end

  def resolve(%MediaResolverQuery{} = query, root_host) when root_host in @non_video_root_hosts do
    resolve_non_video(query, root_host)
  end

  # For youtube.com, we need to rate limit requests. Only do one at a time on this host.
  # Also compute ttl here based upon expire, to localize youtube.com specific logic.
  def resolve(%MediaResolverQuery{} = query, "youtube.com" = root_host) do
    rate_limited_resolve(query, root_host, @youtube_rate_limit, fn ->
      case resolve_with_ytdl(query, root_host, query |> ytdl_format(root_host)) do
        # resolved either as a youtube video or screenshot url
        {:commit, %Ret.ResolvedMedia{uri: %URI{query: youtube_query}} = resolved_media} ->
          # YouTube returns a 'expire' which has timestamp of expiration.
          resolved_media =
            with youtube_query when is_binary(youtube_query) <- youtube_query,
                 parsed_youtube_query <- URI.decode_query(youtube_query),
                 expire when is_binary(expire) <- Map.get(parsed_youtube_query, "expire"),
                 {expire_s, _} <- Integer.parse(expire),
                 ttl_s <- expire_s - System.system_time(:second) do
              # Expire a minute early
              resolved_media |> Map.put(:ttl, ttl_s * 1000 - 60000)
            else
              _ -> resolved_media
            end

          {:commit, resolved_media}

        # Failed to resolve, fall through as a 404
        _ ->
          {:commit, nil}
      end
    end)
  end

  def resolve(%MediaResolverQuery{} = query, root_host) do
    # If we fall through all the known hosts above, we must validate the resolved ip for this host
    # to ensure that it is allowed.
    resolved_ip = HttpUtils.resolve_ip(query.url.host)

    case resolved_ip do
      nil ->
        :error

      resolved_ip ->
        if HttpUtils.internal_ip?(resolved_ip) do
          :forbidden
        else
          resolve_with_ytdl(query, root_host, query |> ytdl_format(root_host))
        end
    end
  end

  def resolve_with_ytdl(%MediaResolverQuery{} = query, root_host, ytdl_format) do
    with ytdl_host when is_binary(ytdl_host) <- module_config(:ytdl_host) do
      case fetch_ytdl_response(query, ytdl_format) do
        {:offline_stream, _body} ->
          {:commit,
           resolved(query.url, %{
             expected_content_type: "text/html",
             media_status: :offline_stream,
             thumbnail: RetWeb.Endpoint.static_url() <> "/stream-offline.png"
           })}

        {:rate_limited, _body} ->
          {:commit,
           resolved(query.url, %{
             expected_content_type: "text/html",
             media_status: :rate_limited,
             thumbnail: RetWeb.Endpoint.static_url() <> "/quota-error.png"
           })}

        {:ok, media_url} ->
          if query_ytdl_audio?(query) do
            # For 360 video quality types, we fetch the audio track separately since
            # YouTube serves up a separate webm for audio.
            resolve_with_ytdl_audio(query, media_url)
          else
            {:commit,
             media_url
             |> URI.parse()
             |> resolved(
               %{
                 # TODO we would like to return a content type here but need to understand the response
                 # from youtube-dl better to do so confidently, as it will not always be video
                 # expected_content_type: "video/*"
               }
             )}
          end

        _ ->
          resolve_non_video(query, root_host)
      end
    else
      _err ->
        resolve_non_video(query, root_host)
    end
  end

  def resolve_with_ytdl_audio(%MediaResolverQuery{} = query, video_url) do
    case fetch_ytdl_response(query, ytdl_audio_format(query)) do
      {:ok, audio_url} ->
        if video_url != audio_url do
          {:commit, video_url |> URI.parse() |> resolved(audio_url |> URI.parse(), %{})}
        else
          {:commit, video_url |> URI.parse() |> resolved(%{})}
        end

      _ ->
        {:commit, video_url |> URI.parse() |> resolved(%{})}
    end
  end

  defp fetch_ytdl_response(%MediaResolverQuery{url: %URI{} = uri, quality: quality}, ytdl_format) do
    ytdl_host = module_config(:ytdl_host)

    ytdl_query_args =
      %{
        format: ytdl_format,
        url: URI.to_string(uri),
        playlist_items: 1
      }
      |> ytdl_add_user_agent_for_quality(quality)

    ytdl_query = URI.encode_query(ytdl_query_args)

    case "#{ytdl_host}/api/info?#{ytdl_query}" |> retry_get_until_valid_ytdl_response do
      %HTTPoison.Response{status_code: 200, body: body} ->
        case body |> Poison.decode() do
          {:ok, json} ->
            media_info = Map.get(json, "info")
            # Prefer "manifest_url" when available so the client can do adaptive bitrate handling
            {:ok, Map.get(media_info, "manifest_url") || Map.get(media_info, "url")}

          {:error, _} ->
            {:error, "Invalid response from youtube-dl"}
        end

      %HTTPoison.Response{status_code: 500, body: body} ->
        # youtube-dl returns a 500 error, but includes the underlying error in its body text, search for some special cases
        cond do
          String.contains?(body, "is offline") ->
            {:offline_stream, body}

          String.contains?(body, "HTTPError 429") ->
            Statix.increment("ret.media_resolver.ytdl.rate_limited")
            {:rate_limited, body}

          true ->
            {:error, body}
        end

      %HTTPoison.Response{body: body} ->
        {:error, body}
    end
  end

  defp ytdl_add_user_agent_for_quality(args, quality) when quality in [:low_360, :high_360] do
    # See https://github.com/ytdl-org/youtube-dl/issues/15267#issuecomment-370122336
    args
    |> Map.put(:user_agent, "")
  end

  defp ytdl_add_user_agent_for_quality(args, _quality), do: args

  defp resolve_non_video(%MediaResolverQuery{url: %URI{} = uri}, "deviantart.com") do
    Statix.increment("ret.media_resolver.deviant.requests")

    [uri, meta] =
      with client_id when is_binary(client_id) <- module_config(:deviantart_client_id),
           client_secret when is_binary(client_secret) <- module_config(:deviantart_client_secret) do
        page_resp = uri |> URI.to_string() |> retry_get_until_success
        deviant_id = Regex.run(@deviant_id_regex, page_resp.body) |> Enum.at(1)
        token_host = "https://www.deviantart.com/oauth2/token"
        api_host = "https://www.deviantart.com/api/v1/oauth2"

        token =
          "#{token_host}?client_id=#{client_id}&client_secret=#{client_secret}&grant_type=client_credentials"
          |> retry_get_until_success
          |> Map.get(:body)
          |> Poison.decode!()
          |> Map.get("access_token")

        uri =
          "#{api_host}/deviation/#{deviant_id}?access_token=#{token}"
          |> retry_get_until_success
          |> Map.get(:body)
          |> Poison.decode!()
          |> Kernel.get_in(["content", "src"])
          |> URI.parse()

        Statix.increment("ret.media_resolver.deviant.ok")
        # todo: determine appropriate content type here if possible
        [uri, nil]
      else
        _err -> [uri, nil]
      end

    {:commit, uri |> resolved(meta)}
  end

  defp resolve_non_video(
         %MediaResolverQuery{url: %URI{path: "/gifs/" <> _rest} = uri},
         "giphy.com"
       ) do
    resolve_giphy_media_uri(uri, "mp4")
  end

  defp resolve_non_video(
         %MediaResolverQuery{url: %URI{path: "/stickers/" <> _rest} = uri},
         "giphy.com"
       ) do
    resolve_giphy_media_uri(uri, "url")
  end

  defp resolve_non_video(
         %MediaResolverQuery{url: %URI{path: "/videos/" <> _rest} = uri},
         "tenor.com"
       ) do
    {:commit, uri |> resolved(%{expected_content_type: "video/mp4"})}
  end

  defp resolve_non_video(
         %MediaResolverQuery{url: %URI{path: "/gallery/" <> gallery_id} = uri},
         "imgur.com"
       ) do
    [resolved_url, meta] =
      "https://imgur-apiv3.p.mashape.com/3/gallery/#{gallery_id}"
      |> image_data_for_imgur_collection_api_url

    {:commit, (resolved_url || uri) |> resolved(meta)}
  end

  defp resolve_non_video(
         %MediaResolverQuery{url: %URI{path: "/a/" <> album_id} = uri},
         "imgur.com"
       ) do
    [resolved_url, meta] =
      "https://imgur-apiv3.p.mashape.com/3/album/#{album_id}"
      |> image_data_for_imgur_collection_api_url

    {:commit, (resolved_url || uri) |> resolved(meta)}
  end

  defp resolve_non_video(
         %MediaResolverQuery{url: %URI{path: "/models/" <> model_id}} = query,
         "sketchfab.com" = root_host
       ) do
    rate_limited_resolve(query, root_host, @sketchfab_rate_limit, fn ->
      resolve_sketchfab_model(model_id, query)
    end)
  end

  defp resolve_non_video(
         %MediaResolverQuery{url: %URI{path: "/3d-models/" <> model_id}} = query,
         "sketchfab.com" = root_host
       ) do
    model_id = model_id |> String.split("-") |> Enum.at(-1)

    rate_limited_resolve(query, root_host, @sketchfab_rate_limit, fn ->
      resolve_sketchfab_model(model_id, query)
    end)
  end

  defp resolve_non_video(%MediaResolverQuery{} = query, _root_host) do
    maybe_fallback_to_screenshot_opengraph_or_nothing(query)
  end

  defp maybe_fallback_to_screenshot_opengraph_or_nothing(
         %MediaResolverQuery{url: %URI{host: host}, version: _version} = query
       ) do
    # We fell back because we did not match any of the known hosts above, or ytdl resolution failed. So, we need to
    # validate the IP for this host before making further requests.
    resolved_ip = HttpUtils.resolve_ip(host)

    case resolved_ip do
      nil ->
        :error

      resolved_ip ->
        if HttpUtils.internal_ip?(resolved_ip) do
          :forbidden
        else
          fallback_to_screenshot_opengraph_or_nothing(query)
        end
    end
  end

  defp fallback_to_screenshot_opengraph_or_nothing(%MediaResolverQuery{
         url: %URI{host: host} = uri,
         version: version
       }) do
    photomnemonic_endpoint = module_config(:photomnemonic_endpoint)

    # Crawl og tags for hubs rooms + scenes
    is_local_url = host === RetWeb.Endpoint.host()

    case uri
         |> URI.to_string()
         |> retry_head_then_get_until_success(
           headers: [{"Range", "bytes=0-32768"}],
           append_browser_user_agent: true
         ) do
      :error ->
        :error

      %HTTPoison.Response{headers: headers} ->
        content_type = headers |> content_type_from_headers
        has_entity_type = headers |> get_http_header("hub-entity-type") != nil

        if content_type |> String.starts_with?("text/html") do
          if !has_entity_type && !is_local_url && photomnemonic_endpoint do
            case uri |> screenshot_commit_for_uri(content_type, version) do
              :error -> uri |> opengraph_result_for_uri()
              commit -> commit
            end
          else
            uri |> opengraph_result_for_uri()
          end
        else
          {:commit, uri |> resolved(%{expected_content_type: content_type})}
        end
    end
  end

  defp screenshot_commit_for_uri(uri, content_type, version) do
    photomnemonic_endpoint = module_config(:photomnemonic_endpoint)

    query = URI.encode_query(url: uri |> URI.to_string())

    cached_file_result =
      CachedFile.fetch(
        "screenshot-#{query}-#{version}",
        fn path ->
          Statix.increment("ret.media_resolver.screenshot.requests")

          url = "#{photomnemonic_endpoint}/screenshot?#{query}"

          case Download.from(url, path: path) do
            {:ok, _path} -> {:ok, %{content_type: "image/png"}}
            _error -> :error
          end
        end
      )

    case cached_file_result do
      {:ok, file_uri} ->
        meta = %{thumbnail: file_uri |> URI.to_string(), expected_content_type: content_type}

        {:commit, uri |> resolved(meta)}

      {:error, _reason} ->
        :error
    end
  end

  defp opengraph_result_for_uri(uri) do
    case uri
         |> URI.to_string()
         |> retry_get_until_success(
           headers: [{"Range", "bytes=0-32768"}],
           append_browser_user_agent: true
         ) do
      :error ->
        :error

      resp ->
        # note that there exist og:image:type and og:video:type tags we could use,
        # but our OpenGraph library fails to parse them out.
        # also, we could technically be correct to emit an "image/*" content type from the OG image case,
        # but our client right now will be confused by that because some images need to turn into
        # image-like views and some (GIFs) need to turn into video-like views.

        parsed_og = resp.body |> OpenGraph.parse()

        thumbnail =
          if parsed_og && parsed_og.image do
            parsed_og.image
          else
            nil
          end

        meta = %{
          expected_content_type: content_type_from_headers(resp.headers),
          thumbnail: thumbnail
        }

        {:commit, uri |> resolved(meta)}
    end
  end

  defp resolve_sketchfab_model(model_id, %MediaResolverQuery{url: %URI{} = uri, version: version}) do
    [uri, meta] =
      with api_key when is_binary(api_key) <- module_config(:sketchfab_api_key) do
        resolve_sketchfab_model(model_id, api_key, version)
      else
        _err -> [uri, nil]
      end

    {:commit, resolved(uri, meta)}
  end

  defp get_sketchfab_model_zip_url(%{model_id: model_id, api_key: api_key}) do
    case "https://api.sketchfab.com/v3/models/#{model_id}/download"
         |> retry_get_until_success(
           headers: [{"Authorization", "Token #{api_key}"}],
           cap_ms: 15_000,
           expiry_ms: 15_000
         ) do
      :error ->
        {:error, "Failed to get sketchfab metadata"}

      response ->
        case response |> Map.get(:body) |> Poison.decode() do
          {:ok, json} ->
            {:ok, Kernel.get_in(json, ["gltf", "url"])}

          _ ->
            {:error, "Failed to get sketchfab metadata"}
        end
    end
  end

  def download_sketchfab_model_to_path(%{model_id: model_id, api_key: api_key, path: path}) do
    case get_sketchfab_model_zip_url(%{model_id: model_id, api_key: api_key}) do
      {:ok, zip_url} ->
        Download.from(zip_url, path: path)
        {:ok, %{content_type: "model/gltf+zip"}}

      {:error, error} ->
        {:error, error}

      _ ->
        {:error, "Failed to get sketchfab url"}
    end
  end

  defp resolve_sketchfab_model(model_id, api_key, version \\ 1) do
    loader = fn path ->
      Statix.increment("ret.media_resolver.sketchfab.requests")

      case download_sketchfab_model_to_path(%{model_id: model_id, api_key: api_key, path: path}) do
        {:ok, metadata} ->
          Statix.increment("ret.media_resolver.sketchfab.ok")
          {:ok, metadata}

        {:error, _} ->
          Statix.increment("ret.media_resolver.sketchfab.errors")
          :error
      end
    end

    cached_file_result = CachedFile.fetch("sketchfab-#{model_id}-#{version}", loader)

    case cached_file_result do
      {:ok, uri} -> [uri, %{expected_content_type: "model/gltf+zip"}]
      {:error, _reason} -> :error
    end
  end

  defp resolve_giphy_media_uri(%URI{} = uri, preferred_type) do
    Statix.increment("ret.media_resolver.giphy.requests")

    [uri, meta] =
      with api_key when is_binary(api_key) <- module_config(:giphy_api_key) do
        gif_id = uri.path |> String.split("/") |> List.last() |> String.split("-") |> List.last()

        original_image =
          "https://api.giphy.com/v1/gifs/#{gif_id}?api_key=#{api_key}"
          |> retry_get_until_success
          |> Map.get(:body)
          |> Poison.decode!()
          |> Kernel.get_in(["data", "images", "original"])

        # todo: determine appropriate content type here if possible
        [(original_image[preferred_type] || original_image["url"]) |> URI.parse(), nil]
      else
        _err -> [uri, nil]
      end

    {:commit, uri |> resolved(meta)}
  end

  defp image_data_for_imgur_collection_api_url(imgur_api_url) do
    with headers when is_list(headers) <- get_imgur_headers() do
      image_data =
        imgur_api_url
        |> retry_get_until_success(headers: headers)
        |> Map.get(:body)
        |> Poison.decode!()
        |> Kernel.get_in(["data", "images"])
        |> List.first()

      image_url = URI.parse(image_data["link"])
      meta = %{expected_content_type: image_data["type"]}
      [image_url, meta]
    else
      _err -> [nil, nil]
    end
  end

  # Performs a GET until we get response with a valid status code from ytdl.
  #
  # "Valid" here means 200, 400, and 500 since that indicates the server successfully
  # attempted to resolve the video URL(s), or we gave it invalid input. If we get
  # a different status code, this could indicate an outage or error in the
  # request.
  #
  # https://youtube-dl-api-server.readthedocs.io/en/latest/api.html#api-methods
  defp retry_get_until_valid_ytdl_response(url) do
    retry with: exponential_backoff() |> randomize |> cap(1_000) |> expiry(10_000) do
      Statix.increment("ret.media_resolver.ytdl.requests")

      case HTTPoison.get(url) do
        {:ok, %HTTPoison.Response{status_code: status_code} = resp}
        when status_code in @ytdl_valid_status_codes ->
          Statix.increment("ret.media_resolver.ytdl.ok")
          resp

        _ ->
          Statix.increment("ret.media_resolver.ytdl.errors")
          :error
      end
    after
      result -> result
    else
      error -> error
    end
  end

  defp get_root_host(nil) do
    nil
  end

  defp get_root_host(host) do
    # Drop subdomains
    host |> String.split(".") |> Enum.slice(-2..-1) |> Enum.join(".")
  end

  defp get_imgur_headers() do
    with client_id when is_binary(client_id) <- module_config(:imgur_client_id),
         api_key when is_binary(api_key) <- module_config(:imgur_mashape_api_key) do
      [{"Authorization", "Client-ID #{client_id}"}, {"X-Mashape-Key", api_key}]
    else
      _err -> nil
    end
  end

  defp rate_limited_resolve(query, root_host, limits, func, depth \\ 0) do
    if depth < @max_await_for_rate_limit_s * 2 do
      case ExRated.check_rate(root_host, limits[:scale], limits[:limit]) do
        {:error, _} ->
          :timer.sleep(500)
          rate_limited_resolve(query, root_host, limits, func, depth + 1)

        _ ->
          func.()
      end
    else
      {:error, "Rate limiter timeout"}
    end
  end

  def resolved(:error), do: nil
  def resolved(%URI{} = uri), do: %Ret.ResolvedMedia{uri: uri}
  def resolved(%URI{} = uri, meta), do: %Ret.ResolvedMedia{uri: uri, meta: meta}

  def resolved(%URI{} = uri, %URI{} = audio_uri, meta),
    do: %Ret.ResolvedMedia{uri: uri, audio_uri: audio_uri, meta: meta}

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end

  defp ytdl_resolution(%MediaResolverQuery{quality: :low}), do: "[height<=480]"
  defp ytdl_resolution(%MediaResolverQuery{quality: :low_360}), do: "[height<=1440]"
  defp ytdl_resolution(%MediaResolverQuery{quality: :high_360}), do: "[height<=2160]"
  defp ytdl_resolution(_query), do: "[height<=720]"

  defp ytdl_qualifier(%MediaResolverQuery{quality: quality}) when quality in [:low, :high],
    do: "best"

  # for 360, we always grab dedicated audio track
  defp ytdl_qualifier(_query), do: "bestvideo"

  defp query_ytdl_audio?(%MediaResolverQuery{quality: quality}) when quality in [:low, :high],
    do: false

  defp query_ytdl_audio?(_query), do: true

  defp ytdl_format(query, "crunchyroll.com") do
    resolution = query |> ytdl_resolution
    ext = query |> ytdl_ext

    # Prefer a version with baked in (english) subtitles. Client locale should eventually determine this
    crunchy_format =
      ["best#{ext}[format_id*=hardsub-enUS]#{resolution}", "best#{ext}[format_id*=hardsub-enUS]"]
      |> Enum.join("/")

    crunchy_format <> "/" <> ytdl_format(query, nil)
  end

  defp ytdl_format(query, _root_host) do
    qualifier = query |> ytdl_qualifier
    resolution = query |> ytdl_resolution
    ext = query |> ytdl_ext
    ytdl_format(qualifier, resolution, ext)
  end

  defp ytdl_audio_format(query) do
    qualifier = "bestaudio"
    resolution = query |> ytdl_resolution
    ext = query |> ytdl_ext
    ytdl_format(qualifier, resolution, ext)
  end

  defp ytdl_format(qualifier, resolution, ext) do
    [
      "#{qualifier}#{ext}[protocol*=http]#{resolution}[format_id!=0]",
      "#{qualifier}#{ext}[protocol*=m3u8]#{resolution}[format_id!=0]",
      "#{qualifier}#{ext}[protocol*=http][format_id!=0]",
      "#{qualifier}#{ext}[protocol*=m3u8][format_id!=0]"
    ]
    |> Enum.join("/")
  end

  def ytdl_ext(%MediaResolverQuery{supports_webm: false}), do: "[ext=mp4]"
  def ytdl_ext(_query), do: ""
end
