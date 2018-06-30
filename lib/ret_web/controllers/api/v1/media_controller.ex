defmodule RetWeb.Api.V1.MediaController do
  use RetWeb, :controller

  @resolvable_url_hosts ["www.youtube.com", "youtube.com"]

  def create(conn, %{"media" => %{"url" => url}} = params) do
    index =
      case params do
        %{"media" => %{"index" => index}} -> index
        _ -> "0"
      end

    handle_url(conn, URI.parse(url), index)
  end

  defp handle_url(conn, %URI{host: nil}, _index) do
    conn |> send_resp(404, "")
  end

  defp handle_url(conn, %URI{host: host} = uri, index) when host in @resolvable_url_hosts do
    render_response_for_uri_and_index(conn, uri, index)
  end

  defp handle_url(conn, %URI{} = uri, index) do
    render_response_for_uri_and_index(conn, uri, index)
  end

  def render_response_for_uri_and_index(conn, uri, index) do
    raw = gen_farspark_url(uri, index, "raw", "")

    images = %{
      "png" => gen_farspark_url(uri, index, "extract", ".png"),
      "jpg" => gen_farspark_url(uri, index, "extract", ".jpg")
    }

    render(conn, "show.json", raw: raw, images: images)
  end

  defp gen_farspark_url(uri, index, method, extension) do
    path =
      "/#{method}/0/0/0/#{index}/#{Base.url_encode64(URI.to_string(uri), padding: false)}#{
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
