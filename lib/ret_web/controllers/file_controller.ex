defmodule RetWeb.FileController do
  use RetWeb, :controller

  alias Ret.{OwnedFile, Storage, Repo}

  def show(conn, %{"id" => <<uuid::binary-size(36)>>, "token" => token}) do
    render_file_with_token(conn, uuid, token)
  end

  def show(conn, %{"id" => <<uuid::binary-size(36), ".html">>, "token" => token}) do
    case Storage.fetch(uuid, token) do
      {:ok, %{"content_type" => content_type}, _stream} ->
        image_url =
          uuid
          |> Ret.Storage.uri_for(content_type)
          |> Map.put(:query, URI.encode_query(token: token))
          |> URI.to_string()

        conn |> render("show.html", image_url: image_url)

      {:error, :not_found} ->
        conn |> send_resp(404, "")

      {:error, :not_allowed} ->
        conn |> send_resp(401, "")
    end
  end

  def show(conn, %{
        "id" => <<uuid::binary-size(36), ".", _extension::binary>>,
        "token" => token
      }) do
    render_file_with_token(conn, uuid, token)
  end

  def show(conn, %{"id" => <<uuid::binary-size(36)>>}) do
    render_file_with_token_from_header(conn, uuid)
  end

  def show(conn, %{"id" => <<uuid::binary-size(36), ".", _extension::binary>>}) do
    render_file_with_token_from_header(conn, uuid)
  end

  defp render_file_with_token_from_header(conn, uuid) do
    case conn |> get_req_header("authorization") do
      [<<"Token ", token::binary>>] ->
        render_file_with_token(conn, uuid, token)

      _ ->
        render_file_with_token(conn, uuid, nil)
    end
  end

  defp render_file_with_token(conn, uuid, token) do
    {uuid, token}
    |> resolve_fetch_args
    |> fetch_and_render(conn)
  end

  # Given a tuple of a UUID and a (optional) user specified token, check to see if there is a OwnedFile
  # record for the given UUID. If, so, return it, since we want to pass that to Ret.Storage.fetch.
  #
  # Otherwise return the passed in tuple, which will be used as-is.
  defp resolve_fetch_args({uuid, _token} = args) do
    case OwnedFile |> Repo.get_by(owned_file_uuid: uuid) do
      %OwnedFile{} = owned_file -> owned_file
      _ -> args
    end
  end

  defp fetch_and_render({_uuid, nil}, conn) do
    conn |> send_resp(401, "")
  end

  defp fetch_and_render({uuid, token}, conn) do
    Storage.fetch(uuid, token) |> render_fetch_result(conn)
  end

  defp fetch_and_render(%OwnedFile{} = owned_file, conn) do
    owned_file |> Storage.fetch() |> render_fetch_result(conn)
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
