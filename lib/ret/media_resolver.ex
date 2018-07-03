defmodule Ret.MediaResolver do
  use Retry

  @ytdl_valid_status_codes [200, 302, 500]
  @success_status_codes [200]

  @ytdl_root_hosts [
    "youtube.com",
    "imgur.com",
    "instagram.com",
    "soundcloud.com",
    "tumblr.com",
    "facebook.com",
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

  def resolve(%URI{} = uri, root_host) when root_host in @ytdl_root_hosts do
    with ytdl_host when is_binary(ytdl_host) <- resolver_config(:ytdl_host) do
      ytdl_format = "best[protocol*=http]"
      encoded_url = uri |> URI.to_string() |> URI.encode()
      ytdl_url = "#{ytdl_host}/api/play?format=#{URI.encode(ytdl_format)}&url=#{encoded_url}"
      ytdl_resp = retry_get_until_valid_ytdl_response(ytdl_url)

      case ytdl_resp do
        %HTTPoison.Response{status_code: 302, headers: headers} ->
          {:commit, headers |> media_url_from_ytdl_headers}

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
        page_resp = retry_get_until_success(uri |> URI.to_string())
        deviant_id = Regex.run(@deviant_id_regex, page_resp.body) |> Enum.at(1)
        token_host = "https://www.deviantart.com/oauth2/token"
        api_host = "https://www.deviantart.com/api/v1/oauth2"

        token_url =
          "#{token_host}?client_id=#{client_id}&client_secret=#{client_secret}&grant_type=client_credentials"

        token_resp = retry_get_until_success(token_url)
        token = token_resp.body |> Poison.decode!() |> Kernel.get_in(["access_token"])

        api_url = "#{api_host}/deviation/#{deviant_id}?access_token=#{token}"
        api_resp = retry_get_until_success(api_url)

        api_resp.body |> Poison.decode!() |> Kernel.get_in(["content", "src"]) |> URI.parse()
      else
        _err -> uri
      end

    {:commit, uri |> URI.to_string()}
  end

  defp resolve_non_video(%URI{} = uri, "giphy.com") do
    uri =
      with api_key when is_binary(api_key) <- resolver_config(:giphy_api_key) do
        gif_id = uri.path |> String.split("/") |> List.last() |> String.split("-") |> List.last()
        giphy_api_url = "https://api.giphy.com/v1/gifs/#{gif_id}?api_key=#{api_key}"
        giphy_resp = retry_get_until_success(giphy_api_url)

        original_image =
          giphy_resp.body |> Poison.decode!() |> Kernel.get_in(["data", "images", "original"])

        (original_image["mp4"] || original_image["url"]) |> URI.parse()
      else
        _err -> uri
      end

    {:commit, uri |> URI.to_string()}
  end

  defp resolve_non_video(%URI{path: "/gallery/" <> gallery_id} = uri, "imgur.com") do
    imgur_api_url = "https://imgur-apiv3.p.mashape.com/3/gallery/#{gallery_id}"
    uri = image_uri_for_imgur_collection_api_url(imgur_api_url) || uri

    {:commit, uri |> URI.to_string()}
  end

  defp resolve_non_video(%URI{path: "/a/" <> album_id} = uri, "imgur.com") do
    imgur_api_url = "https://imgur-apiv3.p.mashape.com/3/album/#{album_id}"
    uri = image_uri_for_imgur_collection_api_url(imgur_api_url) || uri

    {:commit, uri |> URI.to_string()}
  end

  defp resolve_non_video(%URI{} = uri, _root_host) do
    # Fall back on og: tags
    resp = retry_get_until_success(uri |> URI.to_string())

    uri =
      case resp.body |> OpenGraph.parse() do
        %{video: video} -> video |> URI.parse()
        %{image: image} -> image |> URI.parse()
        _ -> uri
      end

    {:commit, uri |> URI.to_string()}
  end

  defp image_uri_for_imgur_collection_api_url(imgur_api_url) do
    with headers when is_list(headers) <- get_imgur_headers() do
      imgur_resp = retry_get_until_success(imgur_api_url, headers)

      image_id =
        imgur_resp.body
        |> Poison.decode!()
        |> Kernel.get_in(["data", "images"])
        |> List.first()
        |> Kernel.get_in(["id"])

      image_uri_for_imgur_id(image_id)
    else
      _err -> nil
    end
  end

  defp image_uri_for_imgur_id(image_id) do
    with headers when is_list(headers) <- get_imgur_headers() do
      imgur_api_url = "https://imgur-apiv3.p.mashape.com/3/image/#{image_id}"
      imgur_resp = retry_get_until_success(imgur_api_url, headers)

      imgur_resp.body
      |> Poison.decode!()
      |> Kernel.get_in(["data", "link"])
      |> URI.parse()
    else
      _err -> nil
    end
  end

  defp retry_get_until_success(url, headers \\ []) do
    retry with: exp_backoff() |> randomize |> cap(5_000) |> expiry(10_000) do
      case HTTPoison.get(url, headers) do
        {:ok, %HTTPoison.Response{status_code: status_code} = resp}
        when status_code in @success_status_codes ->
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
end
