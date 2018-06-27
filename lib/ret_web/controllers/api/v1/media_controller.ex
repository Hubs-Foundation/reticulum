defmodule RetWeb.Api.V1.MediaController do
  use RetWeb, :controller

  def create(conn, %{"media" => %{"url" => url}}) do
    path = "/raw/0/0/0/0/#{Base.url_encode64(url, padding: false)}"
    host = Application.get_env(:ret, :farspark_host)
    raw_image_url = "#{host}/#{gen_signature(path)}#{path}"
    render(conn, "show.json", %{raw_image_url: raw_image_url})
  end

  defp gen_signature(path) do
    key = Application.get_env(:ret, :farspark_signature_key) |> Base.decode16!(case: :lower)
    salt = Application.get_env(:ret, :farspark_signature_salt) |> Base.decode16!(case: :lower)

    :sha256
    |> :crypto.hmac(key, salt <> path)
    |> Base.url_encode64(padding: false)
  end
end
