defmodule Ret.ResolvedMedia do
  @enforce_keys [:uri]
  defstruct [:uri, :meta]
end

defmodule Ret.MediaResolver do
  use Retry

  @ytdl_valid_status_codes [200, 302, 500]

  @ytdl_root_hosts [
    # "youtube.com",
    "imgur.com",
    # "instagram.com",
    # "soundcloud.com",
    "tumblr.com",
    # "facebook.com",
    "google.com",
    "gfycat.com",
    "flickr.com",
    "dropbox.com",
    "cloudflare.com"
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

  def resolve(%URI{} = uri, root_host) when root_host in @ytdl_root_hosts do
    with ytdl_host when is_binary(ytdl_host) <- resolver_config(:ytdl_host) do
      ytdl_format = "best[protocol*=http]"
      encoded_url = uri |> URI.to_string() |> URI.encode()

      ytdl_resp =
        "#{ytdl_host}/api/play?format=#{URI.encode(ytdl_format)}&url=#{encoded_url}"
        |> retry_get_until_valid_ytdl_response

      case ytdl_resp do
        %HTTPoison.Response{status_code: 302, headers: headers} ->
          {:commit, headers |> media_url_from_ytdl_headers |> resolved}

        _ ->
          resolve_non_video(uri, root_host)
      end
    else
      _err ->
        resolve_non_video(uri, root_host)
    end
  end

  def resolve(%URI{} = uri, root_host) do
    resolve_non_video(uri, root_host)
  end

  defp resolve_non_video(%URI{} = uri, "deviantart.com") do
    uri =
      with client_id when is_binary(client_id) <- resolver_config(:deviantart_client_id),
           client_secret when is_binary(client_secret) <-
             resolver_config(:deviantart_client_secret) do
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

        "#{api_host}/deviation/#{deviant_id}?access_token=#{token}"
        |> retry_get_until_success
        |> Map.get(:body)
        |> Poison.decode!()
        |> Kernel.get_in(["content", "src"])
        |> URI.parse()
      else
        _err -> uri
      end

    {:commit, uri |> resolved}
  end

  defp resolve_non_video(%URI{path: "/gifs/" <> _rest} = uri, "giphy.com") do
    resolve_giphy_media_uri(uri, "mp4")
  end

  defp resolve_non_video(%URI{path: "/stickers/" <> _rest} = uri, "giphy.com") do
    resolve_giphy_media_uri(uri, "url")
  end

  defp resolve_non_video(%URI{path: "/gallery/" <> gallery_id} = uri, "imgur.com") do
    resolved_uri =
      "https://imgur-apiv3.p.mashape.com/3/gallery/#{gallery_id}"
      |> image_uri_for_imgur_collection_api_url

    {:commit, (resolved_uri || uri) |> resolved}
  end

  defp resolve_non_video(%URI{path: "/a/" <> album_id} = uri, "imgur.com") do
    resolved_url =
      "https://imgur-apiv3.p.mashape.com/3/album/#{album_id}"
      |> image_uri_for_imgur_collection_api_url

    {:commit, (resolved_url || uri) |> resolved}
  end

  defp resolve_non_video(
         %URI{host: "poly.google.com", path: "/view/" <> asset_id} = uri,
         "google.com"
       ) do
    [uri, meta] =
      with api_key when is_binary(api_key) <- resolver_config(:google_poly_api_key) do
        payload =
          "https://poly.googleapis.com/v1/assets/#{asset_id}?key=#{api_key}"
          |> retry_get_until_success
          |> Map.get(:body)
          |> Poison.decode!()

        meta =
          %{}
          |> Map.put(:name, payload["displayName"])
          |> Map.put(:author, payload["authorName"])
          |> Map.put(:license, payload["license"])

        formats = payload |> Map.get("formats")

        uri =
          (Enum.find(formats, &(&1["formatType"] == "GLTF2")) ||
             Enum.find(formats, &(&1["formatType"] == "GLTF")))
          |> Kernel.get_in(["root", "url"])
          |> URI.parse()

        [uri, meta]
      else
        _err -> uri
      end

    {:commit, uri |> resolved(meta)}
  end

  defp resolve_non_video(%URI{} = uri, _root_host) do
    # Fall back on og: tags
    uri =
      case uri |> URI.to_string() |> retry_get_until_success([{"Range", "bytes=0-32768"}]) do
        :error ->
          uri

        resp ->
          case resp.body |> OpenGraph.parse() do
            %{video: video} when is_binary(video) -> video |> URI.parse()
            %{image: image} when is_binary(image) -> image |> URI.parse()
            _ -> uri
          end
      end

    uri = {:commit, uri |> resolved}
  end

  defp resolve_giphy_media_uri(%URI{} = uri, preferred_type) do
    uri =
      with api_key when is_binary(api_key) <- resolver_config(:giphy_api_key) do
        gif_id = uri.path |> String.split("/") |> List.last() |> String.split("-") |> List.last()

        original_image =
          "https://api.giphy.com/v1/gifs/#{gif_id}?api_key=#{api_key}"
          |> retry_get_until_success
          |> Map.get(:body)
          |> Poison.decode!()
          |> Kernel.get_in(["data", "images", "original"])

        (original_image[preferred_type] || original_image["url"]) |> URI.parse()
      else
        _err -> uri
      end

    {:commit, uri |> resolved}
  end

  defp image_uri_for_imgur_collection_api_url(imgur_api_url) do
    with headers when is_list(headers) <- get_imgur_headers() do
      imgur_api_url
      |> retry_get_until_success(headers)
      |> Map.get(:body)
      |> Poison.decode!()
      |> Kernel.get_in(["data", "images"])
      |> List.first()
      |> Map.get("id")
      |> image_uri_for_imgur_id
    else
      _err -> nil
    end
  end

  defp image_uri_for_imgur_id(image_id) do
    with headers when is_list(headers) <- get_imgur_headers() do
      "https://imgur-apiv3.p.mashape.com/3/image/#{image_id}"
      |> retry_get_until_success(headers)
      |> Map.get(:body)
      |> Poison.decode!()
      |> Kernel.get_in(["data", "link"])
      |> URI.parse()
    else
      _err -> nil
    end
  end

  defp retry_get_until_success(url, headers \\ []) do
    retry with: exp_backoff() |> randomize |> cap(5_000) |> expiry(10_000) do
      case HTTPoison.get(url, headers, follow_redirect: true) do
        {:ok, %HTTPoison.Response{status_code: status_code} = resp}
        when status_code >= 200 and status_code < 300 ->
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

  defp resolver_config(key) do
    Application.get_env(:ret, Ret.MediaResolver)[key]
  end

  defp get_imgur_headers() do
    with client_id when is_binary(client_id) <- resolver_config(:imgur_client_id),
         api_key when is_binary(api_key) <- resolver_config(:imgur_mashape_api_key) do
      [{"Authorization", "Client-ID #{client_id}"}, {"X-Mashape-Key", api_key}]
    else
      _err -> nil
    end
  end

  def resolved(%URI{} = uri) do
    %Ret.ResolvedMedia{uri: uri}
  end

  def resolved(%URI{} = uri, meta) do
    %Ret.ResolvedMedia{uri: uri, meta: meta}
  end
end
