defmodule RetWeb.UploadController do
  use RetWeb, :controller

  def show(conn, %{"id" => <<upload_id::binary-size(36)>>}) do
    handle(conn, upload_id)
  end

  def show(conn, %{"id" => <<upload_id::binary-size(36), ".", _extension::binary>>}) do
    handle(conn, upload_id)
  end

  defp handle(conn, upload_id) do
    case conn |> get_req_header("authorization") do
      [<<"Token ", token::binary>>] ->
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

      _ ->
        conn |> send_resp(401, "")
    end
  end
end
