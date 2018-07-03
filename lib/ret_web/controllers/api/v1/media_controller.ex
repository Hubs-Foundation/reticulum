defmodule RetWeb.Api.V1.MediaController do
  use RetWeb, :controller
  use Retry

  def create(conn, %{"media" => %{"url" => url, "index" => index}}) do
    resolve_and_render(conn, url, index |> Integer.parse())
  end

  def create(conn, %{"media" => %{"url" => url}}) do
    resolve_and_render(conn, url, 0)
  end

  defp resolve_and_render(conn, url, index) do
    case Cachex.fetch(:media_urls, url) do
      {_status, media_url} when is_binary(media_url) ->
        render_resolved_media_url(conn, media_url, index)

      _ ->
        conn |> send_resp(404, "")
    end
  end

  defp render_resolved_media_url(conn, media_url, index) do
    raw = gen_farspark_url(media_url, index, "raw", "")

    images = %{
      "png" => gen_farspark_url(media_url, index, "extract", ".png"),
      "jpg" => gen_farspark_url(media_url, index, "extract", ".jpg")
    }

    conn |> render("show.json", raw: raw, images: images)
  end

  defp gen_farspark_url(url, index, method, extension) do
    path = "/#{method}/0/0/0/#{index}/#{Base.url_encode64(url, padding: false)}#{extension}"

    host = Application.get_env(:ret, :farspark_host)
    "#{host}/#{gen_signature(path)}#{path}"
  end

  defp gen_signature(path) do
    key = Application.get_env(:ret, :farspark_signature_key) |> Base.decode16!(case: :lower)
    salt = Application.get_env(:ret, :farspark_signature_salt) |> Base.decode16!(case: :lower)

    :sha256
    |> :crypto.hmac(key, salt <> path)
    |> Base.url_encode64(padding: false)
  end
end
