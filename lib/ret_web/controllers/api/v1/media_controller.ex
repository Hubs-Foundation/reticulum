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
        "promotion_mode" => "with_token"
      }) do
    store_and_render_upload(conn, upload, MIME.from_path(filename), SecureRandom.hex())
  end

  def create(conn, %{
        "media" => %Plug.Upload{content_type: content_type} = upload,
        "promotion_mode" => "with_token"
      }) do
    store_and_render_upload(conn, upload, content_type, SecureRandom.hex())
  end

  def create(conn, %{"media" => %Plug.Upload{filename: filename, content_type: "application/octet-stream"} = upload}) do
    store_and_render_upload(conn, upload, MIME.from_path(filename))
  end

  def create(conn, %{"media" => %Plug.Upload{content_type: content_type} = upload}) do
    store_and_render_upload(conn, upload, content_type)
  end

  defp store_and_render_upload(conn, %Plug.Upload{} = upload, content_type, promotion_token \\ nil) do
    access_token = SecureRandom.hex()

    case Ret.Storage.store(upload, content_type, access_token, promotion_token) do
      {:ok, uuid} ->
        origin_uri = Ret.Storage.uri_for(uuid, content_type)

        raw_uri =
          case content_type do
            "application/pdf" -> gen_farspark_url(origin_uri, 0, "raw", "") |> URI.parse()
            _ -> origin_uri
          end

        conn
        |> render(
          "show.json",
          file_id: uuid,
          origin: origin_uri |> URI.to_string(),
          raw: raw_uri |> URI.to_string(),
          meta: %{access_token: access_token, promotion_token: promotion_token, expected_content_type: content_type}
        )

      {:error, :not_allowed} ->
        conn |> send_resp(401, "")
    end
  end

  defp resolve_and_render(conn, url, index) do
    ua =
      conn
      |> Plug.Conn.get_req_header("user-agent")
      |> List.first()
      |> UAParser.parse()

    supports_webm = ua.family != "Safari" && ua.family != "Mobile Safari"

    case Cachex.fetch(:media_urls, %Ret.MediaResolverQuery{url: url, supports_webm: supports_webm}) do
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

    conn
    |> render("show.json", origin: uri |> URI.to_string(), raw: raw, meta: meta)
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
