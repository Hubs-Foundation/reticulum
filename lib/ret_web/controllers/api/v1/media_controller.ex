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
      {_status, %Ret.ResolvedMedia{} = resolved_media} ->
        render_resolved_media(conn, resolved_media, index)

      _ ->
        conn |> send_resp(404, "")
    end
  end

  defp render_resolved_media(
         conn,
         %Ret.ResolvedMedia{uri: uri, meta: meta},
         index
       ) do
    raw = gen_farspark_url(uri, index, "raw", "")

    images = %{
      "png" => gen_farspark_url(uri, index, "extract", ".png"),
      "jpg" => gen_farspark_url(uri, index, "extract", ".jpg")
    }

    conn
    |> render("show.json", origin: uri |> URI.to_string(), raw: raw, meta: meta, images: images)
  end

  defp gen_farspark_url(uri, index, method, extension) do
    path =
      "/#{method}/0/0/0/#{index}/#{uri |> URI.to_string() |> Base.url_encode64(padding: false)}#{
        extension
      }"

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
