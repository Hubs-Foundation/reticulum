defmodule Ret.ResolvedMedia do
  @enforce_keys [:uri]
  defstruct [:uri, :meta]
end

defmodule Ret.MediaResolver do
  use Retry
  import Ret.HttpUtils

  @ytdl_valid_status_codes [200, 302, 500]
  @ytdl_default_query "best[protocol*=http]/best[protocol*=m3u8]"
  @ytdl_crunchyroll_query "best[format_id*=hardsub-enUS]/" <> @ytdl_default_query

  @non_video_root_hosts [
    "sketchfab.com",
    "giphy.com",
    "tenor.com"
  ]

  @deviant_id_regex ~r/\"DeviantArt:\/\/deviation\/([^"]+)/

  def resolve(url) when is_binary(url) do
    uri = url |> URI.parse()
    root_host = get_root_host(uri.host)
    resolve(uri, root_host)
  end

  def resolve(%URI{host: nil}, _root_host) do
    {:commit, nil}
  end

  # Necessary short circuit around google.com root_host to skip YT-DL check for Poly
  def resolve(%URI{host: "poly.google.com"} = uri, root_host) do
    resolve_non_video(uri, root_host)
  end

  def resolve(%URI{} = uri, root_host) when root_host in @non_video_root_hosts do
    resolve_non_video(uri, root_host)
  end

  def resolve(%URI{} = uri, "crunchyroll.com" = root_host) do
    # Prefer a version with baked in (english) subtitles. Client locale should eventually determine this
    resolve_with_ytdl(uri, root_host, @ytdl_crunchyroll_query)
  end

  def resolve(%URI{} = uri, root_host) do
    resolve_with_ytdl(uri, root_host)
  end

  def resolve_with_ytdl(%URI{} = uri, root_host, ytdl_format \\ @ytdl_default_query) do
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
    # Fall back on og: tags
    [uri, meta] =
      case uri |> URI.to_string() |> retry_get_until_success([{"Range", "bytes=0-32768"}]) do
        :error ->
          nil

        # note that there exist og:image:type and og:video:type tags we could use,
        # but our OpenGraph library fails to parse them out.

        # also, we could technically be correct to emit an "image/*" content type from the OG image case,
        # but our client right now will be confused by that because some images need to turn into
        # image-like views and some (GIFs) need to turn into video-like views.
        resp ->
          case resp.body |> OpenGraph.parse() do
            %{video: video} when is_binary(video) ->
              [URI.parse(video), %{expected_content_type: "video/*"}]

            # don't send image/*
            %{image: image} when is_binary(image) ->
              [URI.parse(image), %{}]

            _ ->
              [uri, %{expected_content_type: content_type_from_headers(resp.headers)}]
          end
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
    res =
      "https://api.sketchfab.com/v3/models/#{model_id}/download"
      |> retry_get_until_success([{"Authorization", "Token #{api_key}"}])

    uri =
      case res do
        :error ->
          :error

        res ->
          res
          |> Map.get(:body)
          |> Poison.decode!()
          |> Kernel.get_in(["gltf", "url"])
          |> URI.parse()
      end

    [uri, %{expected_content_type: "model/gltf+zip"}]
  end

  defp resolve_giphy_media_uri(%URI{} = uri, preferred_type) do
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
      case HTTPoison.get(url) do
        {:ok, %HTTPoison.Response{status_code: status_code} = resp}
        when status_code in @ytdl_valid_status_codes ->
          resp

        _ ->
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
end
