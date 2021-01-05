defmodule RetWeb.Api.V1.MediaController do
  use RetWeb, :controller
  use Retry
  alias Ret.Statix

  def create(conn, %{"media" => %{"url" => url, "quality" => quality}, "version" => version}),
    do: resolve_and_render(conn, url, version, String.to_atom(quality))

  def create(conn, %{"media" => %{"url" => url}, "version" => version}), do: resolve_and_render(conn, url, version)
  def create(conn, %{"media" => %{"url" => url}}), do: resolve_and_render(conn, url, 1)

  def create(
        conn,
        %{"media" => %Plug.Upload{filename: filename, content_type: "application/octet-stream"} = upload} = params
      ) do
    desired_content_type = params |> Map.get("desired_content_type")
    promotion_token = params |> promotion_token_for_params

    store_and_render_upload(conn, upload, MIME.from_path(filename), desired_content_type, promotion_token)
  end

  def create(conn, %{"media" => %Plug.Upload{content_type: content_type} = upload} = params) do
    desired_content_type = params |> Map.get("desired_content_type")
    promotion_token = params |> promotion_token_for_params

    store_and_render_upload(conn, upload, content_type, desired_content_type, promotion_token)
  end

  defp promotion_token_for_params(%{"promotion_mode" => "with_token"}), do: SecureRandom.hex()
  defp promotion_token_for_params(_params), do: nil

  defp store_and_render_upload(conn, upload, content_type, nil = _desired_content_type, promotion_token) do
    store_and_render_upload(conn, upload, content_type, promotion_token)
  end

  defp store_and_render_upload(conn, upload, content_type, desired_content_type, promotion_token) do
    case Ret.Speelycaptor.convert(upload, desired_content_type) do
      {:ok, converted_path} ->
        converted_upload = %Plug.Upload{
          path: converted_path,
          filename: upload.filename,
          content_type: desired_content_type
        }

        store_and_render_upload(conn, converted_upload, desired_content_type, promotion_token)

      _ ->
        store_and_render_upload(conn, upload, desired_content_type || content_type, promotion_token)
    end
  end

  defp store_and_render_upload(conn, upload, content_type, promotion_token) do
    access_token = SecureRandom.hex()

    case Ret.Storage.store(upload, content_type, access_token, promotion_token) do
      {:ok, uuid} ->
        uri = Ret.Storage.uri_for(uuid, content_type)

        conn
        |> render(
          "show.json",
          file_id: uuid,
          origin: uri |> URI.to_string(),
          raw: uri |> URI.to_string(),
          meta: %{access_token: access_token, promotion_token: promotion_token, expected_content_type: content_type}
        )

      {:error, :quota} ->
        conn |> send_resp(413, "Unable to store additional content.")

      {:error, :not_allowed} ->
        conn |> send_resp(401, "")
    end
  end

  defp resolve_and_render(conn, url, version, quality \\ nil) do
    quality = quality || default_quality(conn)

    ua =
      conn
      |> Plug.Conn.get_req_header("user-agent")
      |> List.first()
      |> UAParser.parse()

    supports_webm = ua.family != "Safari" && ua.family != "Mobile Safari"

    query = %Ret.MediaResolverQuery{
      url: url,
      supports_webm: supports_webm,
      quality: quality,
      version: version
    }

    case Cachex.fetch(:media_urls, query) do
      {_status, nil} ->
        Statix.increment("ret.media_resolver.404")
        conn |> send_resp(404, "")

      {_status, %Ret.ResolvedMedia{ttl: ttl} = resolved_media} ->
        if ttl do
          Cachex.expire(:media_urls, query, :timer.seconds(ttl / 1000))
        end

        Statix.increment("ret.media_resolver.ok")
        render_resolved_media(conn, resolved_media)

      {:error, e} ->
        Statix.increment("ret.media_resolver.500")
        conn |> send_resp(500, e)

      _ ->
        Statix.increment("ret.media_resolver.500")
        conn |> send_resp(500, "Error resolving media")
    end
  end

  defp render_resolved_media(conn, %Ret.ResolvedMedia{uri: uri, audio_uri: audio_uri, meta: meta})
       when audio_uri != nil do
    conn |> render("show.json", origin: uri |> URI.to_string(), origin_audio: audio_uri |> URI.to_string(), meta: meta)
  end

  defp render_resolved_media(conn, %Ret.ResolvedMedia{uri: uri, meta: meta}) do
    conn |> render("show.json", origin: uri |> URI.to_string(), meta: meta)
  end

  defp default_quality(conn) do
    ua =
      conn
      |> Plug.Conn.get_req_header("user-agent")
      |> List.first()
      |> UAParser.parse()

    if ua.os.family == "Android" || ua.os.family == "iOS" do
      :low
    else
      :high
    end
  end
end
