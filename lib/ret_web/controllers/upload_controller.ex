defmodule RetWeb.UploadController do
  use RetWeb, :controller

  def show(conn, %{"id" => <<upload_id::binary-size(36)>>, "token" => token}) do
    fetch_upload(conn, upload_id, token)
  end

  def show(conn, %{"id" => <<upload_id::binary-size(36), ".", _extension::binary>>, "token" => token}) do
    fetch_upload(conn, upload_id, token)
  end

  def show(conn, %{"id" => <<upload_id::binary-size(36)>>}) do
    fetch_upload_with_token_from_header(conn, upload_id)
  end

  def show(conn, %{"id" => <<upload_id::binary-size(36), ".", _extension::binary>>}) do
    fetch_upload_with_token_from_header(conn, upload_id)
  end

  defp fetch_upload(conn, upload_id, token) do
    case Ret.Uploads.fetch(upload_id, token) do
      {:ok, %{"content_type" => content_type, "content_length" => content_length}, stream} ->
        conn =
          conn
          |> put_resp_content_type(content_type)
          |> put_resp_header("content-length", "#{content_length}")
          |> put_resp_header("transfer-encoding", "chunked")
          |> put_resp_header("cache-control", "public, max-age=31536000")
          |> send_chunked(200)

        stream |> Stream.map(&chunk(conn, &1)) |> Stream.run()

        conn

      {:error, :not_found} ->
        conn |> send_resp(400, "")

      {:error, :not_allowed} ->
        conn |> send_resp(401, "")
    end
  end

  defp fetch_upload_with_token_from_header(conn, upload_id) do
    case conn |> get_req_header("authorization") do
      [<<"Token ", token::binary>>] ->
          fetch_upload(conn, upload_id, token)
      _ ->
        conn |> send_resp(401, "")
    end
  end
end
