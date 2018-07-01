defmodule Ret.MediaResolver do
  use Retry

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

  def resolve(url) when is_binary(url) do
    uri = url |> URI.parse()
    root_host = get_root_host(uri.host)
    resolve(uri, root_host)
  end

  def resolve(%URI{host: nil}, _) do
    {:commit, nil}
  end

  def resolve(%URI{} = uri, root_host) when root_host in @ytdl_root_hosts do
    ytdl_host = Application.get_env(:ret, :ytdl_host)

    ytdl_format = "best[protocol*=http]"

    ytdl_url =
      "#{ytdl_host}/api/play?format=#{URI.encode(ytdl_format)}&url=#{
        uri |> URI.to_string() |> URI.encode()
      }"

    ytdl_resp =
      retry with: exp_backoff() |> randomize |> cap(3_000) |> expiry(15_000) do
        HTTPoison.get!(ytdl_url)
      after
        result -> result
      else
        error -> error
      end

    case ytdl_resp do
      %HTTPoison.Response{status_code: 302, headers: headers} ->
        {:ignore, headers |> media_url_from_headers}

      _ ->
        # TODO handle misses here for images, etc
        {:commit, nil}
    end
  end

  def resolve(%URI{} = uri, _root_host) do
    {:commit, uri |> URI.to_string()}
  end

  defp get_root_host(nil) do
    nil
  end

  defp get_root_host(host) do
    # Drop subdomains
    host |> String.split(".") |> Enum.slice(-2..-1) |> Enum.join(".")
  end

  defp media_url_from_headers(headers) do
    headers |> List.keyfind("Location", 0) |> elem(1)
  end
end
