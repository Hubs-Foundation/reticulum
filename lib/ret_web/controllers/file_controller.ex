defmodule RetWeb.FileController do
  use RetWeb, :controller

  alias Ret.{StoredFile, StoredFiles, Repo}

  def show(conn, %{"id" => <<uuid::binary-size(36)>>}) do
    render_file_with_token_from_header(conn, uuid)
  end

  def show(conn, %{"id" => <<uuid::binary-size(36), ".", _extension::binary>>}) do
    render_file_with_token_from_header(conn, uuid)
  end

  def show(conn, %{"id" => <<uuid::binary-size(36)>>, "token" => token}) do
    render_file_with_token(conn, uuid, token)
  end

  def show(conn, %{
        "id" => <<uuid::binary-size(36), ".", _extension::binary>>,
        "token" => token
      }) do
    render_file_with_token(conn, uuid, token)
  end

  defp render_file_with_token_from_header(conn, uuid) do
    case conn |> get_req_header("authorization") do
      [<<"Token ", token::binary>>] ->
        render_file_with_token(conn, uuid, token)

      _ ->
        conn |> send_resp(401, "")
    end
  end

  defp render_file_with_token(conn, uuid, token) do
    {uuid, token}
    |> lookup_stored_file
    |> fetch_and_render(conn)
  end

  # Given a tuple of a UUID and a (optional) user specified token, check to see if there is a StoredFile
  # record for the given UUID. If, so, return it, otherwise return the passed in tuple.
  defp lookup_stored_file({uuid, _token} = args) do
    case StoredFile |> Repo.get_by(stored_file_sid: uuid) do
      %StoredFile{} = stored_file -> stored_file
      _ -> args
    end
  end

  defp fetch_and_render({uuid, token}, conn) do
    StoredFiles.fetch(uuid, token) |> render_fetch_result(conn)
  end

  defp fetch_and_render(%StoredFile{} = stored_file, conn) do
    stored_file |> StoredFiles.fetch() |> render_fetch_result(conn)
  end

  defp render_fetch_result(fetch_result, conn) do
    case fetch_result do
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
end
