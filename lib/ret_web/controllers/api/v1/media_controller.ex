defmodule RetWeb.Api.V1.MediaController do
  use RetWeb, :controller
  use Retry

  def create(conn, %{"media" => %{"url" => url, "index" => index}}) do
    resolve_and_render(conn, url, index)
  end

  def create(conn, %{"media" => %{"url" => url}}) do
    resolve_and_render(conn, url, 0)
  end

  def create(conn, %{
    "media" => %Plug.Upload{filename: filename, content_type: "application/octet-stream"} = upload
  }) do
    render_upload(conn, upload, MIME.from_path(filename))
  end

  def create(conn, %{"media" => %Plug.Upload{content_type: content_type} = upload}) do
    render_upload(conn, upload, content_type)
  end

  defp render_upload(conn, %Plug.Upload{} = upload, content_type) do
    token = SecureRandom.hex()
    ext = MIME.extensions(content_type) |> List.first()

    case Ret.Uploads.store(upload, content_type, token) do
      {:ok, upload_uuid} ->
        upload_host = Application.get_env(:ret, Ret.Uploads)[:host] || RetWeb.Endpoint.url()

        filename = [upload_uuid, ext] |> Enum.reject(&is_nil/1) |> Enum.join(".")
        uri = "#{upload_host}/uploads/#{filename}" |> URI.parse()
        images = images_for_uri_and_index(uri, 0)

        conn
        |> render(
          "show.json",
          origin: uri |> URI.to_string(),
          raw: uri |> URI.to_string(),
          images: images,
          meta: %{access_token: token, expected_content_type: content_type}
        )

      {:error, :not_allowed} ->
        conn |> send_resp(401, "")
    end
  end

  defp resolve_and_render(conn, url, index) do
    case Cachex.fetch(:media_urls, url) do
      {_status, nil} ->
        conn |> send_resp(404, "")

      {_status, %Ret.ResolvedMedia{} = resolved_media} ->
        render_resolved_media(conn, resolved_media, index)

      _ ->
        conn |> send_resp(404, "")
    end
  end

  defp render_resolved_media(conn, %Ret.ResolvedMedia{uri: uri, meta: meta}, index) do
    raw = gen_farspark_url(uri, index, "raw", "")
    images = images_for_uri_and_index(uri, index)

    conn
    |> render("show.json", origin: uri |> URI.to_string(), raw: raw, meta: meta, images: images)
  end

  defp images_for_uri_and_index(uri, index) do
    %{
      "png" => gen_farspark_url(uri, index, "extract", ".png"),
      "jpg" => gen_farspark_url(uri, index, "extract", ".jpg")
    }
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
