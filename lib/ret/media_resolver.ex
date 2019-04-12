defmodule Ret.ResolvedMedia do
  @enforce_keys [:uri]
  defstruct [:uri, :meta]
end

defmodule Ret.MediaResolverQuery do
  @enforce_keys [:url]
  defstruct [:url, supports_webm: true, low_resolution: false]
end

defmodule Ret.MediaResolver do
  use Retry
  import Ret.HttpUtils

  alias Ret.{CachedFile, MediaResolverQuery, Statix}

  @ytdl_valid_status_codes [200, 302, 500]

  @non_video_root_hosts [
    "sketchfab.com",
    "giphy.com",
    "tenor.com"
  ]

  @deviant_id_regex ~r/\"DeviantArt:\/\/deviation\/([^"]+)/

  def resolve(%MediaResolverQuery{url: url} = query) when is_binary(url) do
    uri = url |> URI.parse()
    root_host = get_root_host(uri.host)
    resolve(query |> Map.put(:url, uri), root_host)
  end

  def resolve(%MediaResolverQuery{url: %URI{host: nil}}, _root_host) do
    {:commit, nil}
  end

  # Necessary short circuit around google.com root_host to skip YT-DL check for Poly
  def resolve(%MediaResolverQuery{url: %URI{host: "poly.google.com"} = uri}, root_host) do
    resolve_non_video(uri, root_host)
  end

  def resolve(%MediaResolverQuery{url: %URI{} = uri}, root_host) when root_host in @non_video_root_hosts do
    resolve_non_video(uri, root_host)
  end

  def resolve(%MediaResolverQuery{url: %URI{} = uri} = query, root_host) do
    resolve_with_ytdl(uri, root_host, query |> ytdl_query(root_host))
  end

  def resolve_with_ytdl(%URI{} = uri, root_host, ytdl_format) do
    with ytdl_host when is_binary(ytdl_host) <- module_config(:ytdl_host) do
      encoded_url = uri |> URI.to_string() |> URI.encode()

      ytdl_resp =
        "#{ytdl_host}/api/play?format=#{URI.encode(ytdl_format)}&url=#{encoded_url}"
        |> retry_get_until_valid_ytdl_response

      case ytdl_resp do
        %HTTPoison.Response{status_code: 302, headers: headers} ->
          # todo: it would be really nice to return video/* content type here!
          # but it seems that the way we're using youtube-dl will return a 302 with the
          # direct URL for various non-video files, e.g. PDFs seem to trigger this, so until
          # we figure out how to change that behavior or distinguish between them, we can't
          # be confident that it's video/* in this branch
          meta = %{}

          {:commit, headers |> media_url_from_ytdl_headers |> URI.parse() |> resolved(meta)}

        _ ->
          resolve_non_video(uri, root_host)
      end
    else
      _err ->
        resolve_non_video(uri, root_host)
    end
  end

  defp resolve_non_video(%URI{} = uri, "deviantart.com") do
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

  defp resolve_non_video(%URI{path: "/gifs/" <> _rest} = uri, "giphy.com") do
    resolve_giphy_media_uri(uri, "mp4")
  end

  defp resolve_non_video(%URI{path: "/stickers/" <> _rest} = uri, "giphy.com") do
    resolve_giphy_media_uri(uri, "url")
  end

  defp resolve_non_video(%URI{path: "/videos/" <> _rest} = uri, "tenor.com") do
    {:commit, uri |> resolved(%{expected_content_type: "video/mp4"})}
  end

  defp resolve_non_video(%URI{path: "/gallery/" <> gallery_id} = uri, "imgur.com") do
    [resolved_url, meta] =
      "https://imgur-apiv3.p.mashape.com/3/gallery/#{gallery_id}"
      |> image_data_for_imgur_collection_api_url

    {:commit, (resolved_url || uri) |> resolved(meta)}
  end

  defp resolve_non_video(%URI{path: "/a/" <> album_id} = uri, "imgur.com") do
    [resolved_url, meta] =
      "https://imgur-apiv3.p.mashape.com/3/album/#{album_id}"
      |> image_data_for_imgur_collection_api_url

    {:commit, (resolved_url || uri) |> resolved(meta)}
  end

  defp resolve_non_video(
         %URI{host: "poly.google.com", path: "/view/" <> asset_id} = uri,
         "google.com"
       ) do
    [uri, meta] =
      with api_key when is_binary(api_key) <- module_config(:google_poly_api_key) do
        Statix.increment("ret.media_resolver.poly.requests")

        payload =
          "https://poly.googleapis.com/v1/assets/#{asset_id}?key=#{api_key}"
          |> retry_get_until_success
          |> Map.get(:body)
          |> Poison.decode!()

        meta =
          %{expected_content_type: "model/gltf"}
          |> Map.put(:name, payload["displayName"])
          |> Map.put(:author, payload["authorName"])
          |> Map.put(:license, payload["license"])

        formats = payload |> Map.get("formats")

        uri =
          (Enum.find(formats, &(&1["formatType"] == "GLTF2")) || Enum.find(formats, &(&1["formatType"] == "GLTF")))
          |> Kernel.get_in(["root", "url"])
          |> URI.parse()

        Statix.increment("ret.media_resolver.poly.ok")

        [uri, meta]
      else
        _err -> [uri, nil]
      end

    {:commit, uri |> resolved(meta)}
  end

  defp resolve_non_video(
         %URI{path: "/models/" <> model_id} = uri,
         "sketchfab.com"
       ) do
    resolve_sketchfab_model(model_id, uri)
  end

  defp resolve_non_video(
         %URI{path: "/3d-models/" <> model_id} = uri,
         "sketchfab.com"
       ) do
    model_id = model_id |> String.split("-") |> Enum.at(-1)
    resolve_sketchfab_model(model_id, uri)
  end

  defp resolve_non_video(%URI{} = uri, _root_host) do
    photomnemonic_endpoint = module_config(:photomnemonic_endpoint)

    # For text/html pages we use the screenshotter, otherwise return the raw URL.
    # Try HEAD, if HEAD fails then do a GET and check content type.
    # If HEAD works, check content type.
    case uri |> URI.to_string() |> retry_head_until_success() do
      :error ->
        case uri |> URI.to_string() |> retry_get_until_success([{"Range", "bytes=0-32768"}]) do
          %HTTPoison.Response{headers: headers} = res ->
            content_type = headers |> content_type_from_headers

            if photomnemonic_endpoint && content_type |> String.starts_with?("text/html") do
              screenshot_commit_for_uri(uri, content_type)
            else
              og_tag_commit_for_response(uri, res)
            end

          :error ->
            nil
        end

      %HTTPoison.Response{headers: headers} ->
        content_type = headers |> content_type_from_headers

        if photomnemonic_endpoint && content_type |> String.starts_with?("text/html") do
          screenshot_commit_for_uri(uri, content_type)
        else
          case uri |> URI.to_string() |> retry_get_until_success([{"Range", "bytes=0-32768"}]) do
            :error ->
              nil

            resp ->
              og_tag_commit_for_response(uri, resp)
          end
        end
    end
  end

  defp screenshot_commit_for_uri(uri, content_type) do
    photomnemonic_endpoint = module_config(:photomnemonic_endpoint)
    query = URI.encode_query(url: uri |> URI.to_string())

    cached_file_result =
      CachedFile.fetch("screenshot-#{query}", fn path ->
        Statix.increment("ret.media_resolver.screenshot.requests")
        Download.from("#{photomnemonic_endpoint}/screenshot?#{query}", path: path)

        {:ok, %{content_type: "image/png"}}
      end)

    case cached_file_result do
      {:ok, file_uri} ->
        meta = %{thumbnail: file_uri |> URI.to_string(), expected_content_type: content_type}

        {:commit, uri |> resolved(meta)}

      {:error, _reason} ->
        :error
    end
  end

  defp og_tag_commit_for_response(uri, resp) do
    # note that there exist og:image:type and og:video:type tags we could use,
    # but our OpenGraph library fails to parse them out.
    # also, we could technically be correct to emit an "image/*" content type from the OG image case,
    # but our client right now will be confused by that because some images need to turn into
    # image-like views and some (GIFs) need to turn into video-like views.
    [uri, meta] =
      case resp.body |> OpenGraph.parse() do
        %{video: video} when is_binary(video) ->
          [URI.parse(video), %{expected_content_type: "video/*"}]

        # don't send image/*
        %{image: image} when is_binary(image) ->
          [URI.parse(image), %{}]

        _ ->
          [uri, %{expected_content_type: content_type_from_headers(resp.headers)}]
      end

    {:commit, uri |> resolved(meta)}
  end

  defp resolve_sketchfab_model(model_id, %URI{} = uri) do
    [uri, meta] =
      with api_key when is_binary(api_key) <- module_config(:sketchfab_api_key) do
        resolve_sketchfab_model(model_id, api_key)
      else
        _err -> [uri, nil]
      end

    {:commit, uri |> resolved(meta)}
  end

  defp resolve_sketchfab_model(model_id, api_key) do
    cached_file_result =
      CachedFile.fetch("sketchfab-#{model_id}", fn path ->
        Statix.increment("ret.media_resolver.sketchfab.requests")

        res =
          "https://api.sketchfab.com/v3/models/#{model_id}/download"
          |> retry_get_until_success([{"Authorization", "Token #{api_key}"}])

        case res do
          :error ->
            Statix.increment("ret.media_resolver.sketchfab.errors")

            :error

          res ->
            Statix.increment("ret.media_resolver.sketchfab.ok")

            zip_url =
              res
              |> Map.get(:body)
              |> Poison.decode!()
              |> Kernel.get_in(["gltf", "url"])

            Download.from(zip_url, path: path)

            {:ok, %{content_type: "model/gltf+zip"}}
        end
      end)

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
        |> retry_get_until_success(headers)
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
  # Oddly, valid status codes are 200, 302, and 500 since that indicates
  # the server successfully attempted to resolve the video URL(s). If we get
  # a different status code, this could indicate an outage or error in the
  # request.
  #
  # https://youtube-dl-api-server.readthedocs.io/en/latest/api.html#api-methods
  defp retry_get_until_valid_ytdl_response(url) do
    retry with: exp_backoff() |> randomize |> cap(1_000) |> expiry(10_000) do
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

  defp media_url_from_ytdl_headers(headers) do
    headers |> List.keyfind("Location", 0) |> elem(1)
  end

  defp content_type_from_headers(headers) do
    headers |> List.keyfind("Content-Type", 0) |> elem(1)
  end

  defp get_imgur_headers() do
    with client_id when is_binary(client_id) <- module_config(:imgur_client_id),
         api_key when is_binary(api_key) <- module_config(:imgur_mashape_api_key) do
      [{"Authorization", "Client-ID #{client_id}"}, {"X-Mashape-Key", api_key}]
    else
      _err -> nil
    end
  end

  def resolved(:error) do
    nil
  end

  def resolved(%URI{} = uri) do
    %Ret.ResolvedMedia{uri: uri}
  end

  def resolved(%URI{} = uri, meta) do
    %Ret.ResolvedMedia{uri: uri, meta: meta}
  end

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end

  defp ytdl_resolution(%MediaResolverQuery{low_resolution: true}), do: "480"
  defp ytdl_resolution(_query), do: "720"

  defp ytdl_query(query, "crunchyroll.com") do
    resolution = query |> ytdl_resolution
    ext = query |> ytdl_ext

    # Prefer a version with baked in (english) subtitles. Client locale should eventually determine this
    crunchy_query =
      ["best#{ext}[format_id*=hardsub-enUS][height<=?#{resolution}]", "best#{ext}[format_id*=hardsub-enUS]"]
      |> Enum.join("/")

    crunchy_query <> "/" <> ytdl_query(query, nil)
  end

  defp ytdl_query(query, _root_host) do
    resolution = query |> ytdl_resolution
    ext = query |> ytdl_ext

    [
      "best#{ext}[protocol*=http][height<=?#{resolution}]",
      "best#{ext}[protocol*=m3u8][height<=?#{resolution}]",
      "best#{ext}[protocol*=http]",
      "best#{ext}[protocol*=m3u8]"
    ]
    |> Enum.join("/")
  end

  def ytdl_ext(%MediaResolverQuery{supports_webm: false}), do: "[ext=mp4]"
  def ytdl_ext(_query), do: ""
end
