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
    query = query_for(conn, url, version, quality || default_quality)
    value = Cachex.fetch(:media_urls, query)
    maybe_do_telemetry(value)
    maybe_bump_ttl(value, query)
    render_resolved_media_or_error(conn, value)
  end

  defp query_for(conn, url, version, quality) do
    quality = quality || default_quality(conn)

    ua =
      conn
      |> Plug.Conn.get_req_header("user-agent")
      |> List.first()
      |> UAParser.parse()

    supports_webm = ua.family != "Safari" && ua.family != "Mobile Safari"

    %Ret.MediaResolverQuery{
      url: url,
      supports_webm: supports_webm,
      quality: quality,
      version: version
    }
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

  defp maybe_do_telemetry({:commit, nil}), do: Statix.increment("ret.media_resolver.404")
  defp maybe_do_telemetry({:commit, %Ret.ResolvedMedia{}}), do: Statix.increment("ret.media_resolver.ok")
  defp maybe_do_telemetry({:error, _reason}), do: Statix.increment("ret.media_resolver.500")
  defp maybe_do_telemetry(_), do: nil

  defp maybe_bump_ttl({_status, %Ret.ResolvedMedia{ttl: ttl}}, query) do
    if ttl do
      Cachex.expire(:media_urls, query, :timer.seconds(ttl / 1000))
    end
  end

  defp maybe_bump_ttl(_value, _query), do: nil

  defp render_resolved_media_or_error(conn, {:error, reason}) do
    send_resp(conn, 500, reason)
  end

  defp render_resolved_media_or_error(conn, {_status, nil}) do
    send_resp(conn, 404, "")
  end

  defp render_resolved_media_or_error(conn, {_status, %Ret.ResolvedMedia{} = resolved_media}) do
    render_resolved_media(conn, resolved_media)
  end

  defp render_resolved_media_or_error(conn, _) do
    # We do not expect this code to run, so if it happens, something went wrong
    Statix.increment("ret.media_resolver.unknown_error")
    send_resp(conn, 500, "An unexpected error occurred during media resolution.")
  end

  defp render_resolved_media(conn, %Ret.ResolvedMedia{uri: uri, audio_uri: audio_uri, meta: meta})
       when audio_uri != nil do
    conn |> render("show.json", origin: uri |> URI.to_string(), origin_audio: audio_uri |> URI.to_string(), meta: meta)
  end

  defp render_resolved_media(conn, %Ret.ResolvedMedia{uri: uri, meta: meta}) do
    conn |> render("show.json", origin: uri |> URI.to_string(), meta: meta)
  end
end
