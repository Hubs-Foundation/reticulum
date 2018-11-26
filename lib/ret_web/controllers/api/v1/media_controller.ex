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
        "media" => %Plug.Upload{filename: filename, content_type: "application/octet-stream"} = upload,
        "with_promotion_token" => with_promotion_token
      }) do
    render_upload(conn, upload, MIME.from_path(filename), with_promotion_token)
  end

  def create(conn, %{
        "media" => %Plug.Upload{content_type: content_type} = upload,
        "with_promotion_token" => with_promotion_token
      }) do
    render_upload(conn, upload, content_type, with_promotion_token)
  end

  defp render_upload(conn, %Plug.Upload{} = upload, content_type, with_promotion_token) do
    token = SecureRandom.hex()
    promotion_token = if with_promotion_token, do: SecureRandom.hex(), else: nil

    case Ret.Storage.store(upload, content_type, token, promotion_token) do
      {:ok, uuid} ->
        uri = Ret.Storage.uri_for(uuid, content_type)
        images = images_for_uri_and_index(uri, 0)

        conn
        |> render(
          "show.json",
          file_id: uuid,
          origin: uri |> URI.to_string(),
          raw: uri |> URI.to_string(),
          images: images,
          meta: %{access_token: token, promotion_token: promotion_token, expected_content_type: content_type}
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
    path = "/#{method}/0/0/0/#{index}/#{uri |> URI.to_string() |> Base.url_encode64(padding: false)}#{extension}"

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
