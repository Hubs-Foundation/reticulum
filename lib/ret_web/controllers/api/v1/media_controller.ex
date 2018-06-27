defmodule RetWeb.Api.V1.MediaController do
  use RetWeb, :controller

  def create(conn, %{"media" => %{"url" => url}} = params) do
    index =
      case params do
        %{"media" => %{"index" => index}} -> index
        _ -> "0"
      end

    images = %{
      "raw" => gen_farspark_url(url, index, "raw", ""),
      "extract_png" => gen_farspark_url(url, index, "extract", ".png"),
      "extract_jpg" => gen_farspark_url(url, index, "extract", ".jpg")
    }

    render(conn, "show.json", images: images)
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
