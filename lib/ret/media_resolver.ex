defmodule Ret.MediaResolver do
  use Retry

  @ytdl_url_hosts [
    "www.youtube.com",
    "youtube.com",
    "twitch.tv",
    "www.twitch.tv",
    "imgur.com",
    "instagram.com",
    "www.instagram.com",
    "soundcloud.com",
    "www.soundcloud.com",
    "crunchyroll.com",
    "www.crunchyroll.com",
    "www.tumblr.com",
    "tumblr.com",
    "twitter.com",
    "www.twitter.com",
    "facebook.com",
    "www.facebook.com",
    "periscope.com",
    "www.periscope.com",
    "drive.google.com",
    "gfycat.com",
    "www.gfycat.com",
    "flickr.com",
    "www.flickr.com",
    "dropbox.com",
    "www.dropbox.com",
    "cloudflare.com",
    "www.cloudflare.com"
  ]

  def resolve(url) when is_binary(url) do
    url |> URI.parse() |> resolve
  end

  def resolve(%URI{host: nil}) do
    {:commit, nil}
  end

  def resolve(%URI{host: host} = uri) when host in @ytdl_url_hosts do
    ytdl_host = Application.get_env(:ret, :ytdl_host)
    ytdl_url = "#{ytdl_host}/api/play?url=#{uri |> URI.to_string() |> URI.encode()}"

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
        {:commit, headers |> List.keyfind("Location", 0) |> elem(1)}

      _ ->
        {:commit, nil}
    end
  end

  def resolve(%URI{host: _host} = uri) do
    {:commit, uri |> URI.to_string()}
  end
end
