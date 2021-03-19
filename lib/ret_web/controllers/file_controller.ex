defmodule RetWeb.FileController do
  use RetWeb, :controller
  require Logger

  alias Ret.{OwnedFile, CachedFile, Storage, Repo, AppConfig}

  def show(conn, params) do
    case conn |> get_req_header("x-original-method") do
      ["HEAD"] -> handle(conn, params, :head)
      _ -> handle(conn, params, :show)
    end
  end

  def handle(conn, %{"id" => <<uuid::binary-size(36)>>, "token" => token}, type) do
    render_file_with_token(conn, type, uuid, token)
  end

  def handle(conn, %{"id" => <<uuid::binary-size(36), ".html">>, "token" => token}, :show) do
    case Storage.fetch(uuid, token) do
      {:ok, %{"content_type" => content_type}, _stream} ->
        image_url =
          uuid
          |> Ret.Storage.uri_for(content_type)
          |> Map.put(:query, URI.encode_query(token: token))
          |> URI.to_string()

        app_name =
          AppConfig.get_cached_config_value("translations|en|app-full-name") ||
            AppConfig.get_cached_config_value("translations|en|app-name")

        conn
        |> render("show.html",
          image_url: image_url,
          app_name: app_name
        )

      {:error, :not_found} ->
        conn |> send_resp(404, "")

      {:error, :not_allowed} ->
        conn |> send_resp(401, "")

      {:error, reason} ->
        conn |> send_resp(424, reason)
    end
  end

  def handle(
        conn,
        %{
          "id" => <<uuid::binary-size(36), ".", _extension::binary>>,
          "token" => token
        },
        type
      ) do
    render_file_with_token(conn, type, uuid, token)
  end

  def handle(conn, %{"id" => <<uuid::binary-size(36)>>}, type) do
    render_file_with_token_from_header(conn, type, uuid)
  end

  def handle(conn, %{"id" => <<uuid::binary-size(36), ".", _extension::binary>>}, type) do
    render_file_with_token_from_header(conn, type, uuid)
  end

  defp render_file_with_token_from_header(conn, type, uuid) do
    case conn |> get_req_header("authorization") do
      [<<"Token ", token::binary>>] ->
        render_file_with_token(conn, type, uuid, token)

      _ ->
        render_file_with_token(conn, type, uuid, nil)
    end
  end

  defp render_file_with_token(conn, type, uuid, token) do
    {uuid, token}
    |> resolve_fetch_args
    |> fetch_and_render(conn, type)
  end

  # Given a tuple of a UUID and a (optional) user specified token,
  # check to see if there is an OwnedFile or CachedFile
  # record for the given UUID.
  # If, so, return it, since we want to pass that to Ret.Storage.fetch.
  #
  # Otherwise return the passed in tuple, which will be used as-is.
  defp resolve_fetch_args({uuid, _token} = args) do
    case OwnedFile |> Repo.get_by(owned_file_uuid: uuid) do
      %OwnedFile{} = owned_file ->
        owned_file

      _ ->
        case CachedFile |> Repo.get_by(file_uuid: uuid) do
          %CachedFile{} = cached_file -> cached_file
          _ -> args
        end
    end
  end

  defp fetch_and_render({_uuid, nil}, conn, _type) do
    conn |> send_resp(401, "")
  end

  defp fetch_and_render({uuid, token}, conn, type) do
    Storage.fetch(uuid, token) |> render_fetch_result(conn, type)
  end

  defp fetch_and_render(%OwnedFile{} = owned_file, conn, type) do
    owned_file |> Storage.fetch() |> render_fetch_result(conn, type)
  end

  defp fetch_and_render(%CachedFile{} = cached_file, conn, type) do
    cached_file |> Storage.fetch() |> render_fetch_result(conn, type)
  end

  defp render_fetch_result(fetch_result, conn, :head) do
    case fetch_result do
      {:ok, %{"content_type" => content_type, "content_length" => content_length}, _stream} ->
        conn
        |> put_resp_content_type(content_type, nil)
        |> put_resp_header("content-length", "#{content_length}")
        |> put_resp_header("accept-ranges", "bytes")
        |> send_resp(200, "")

      {:error, :not_found} ->
        conn |> send_resp(400, "")

      {:error, :not_allowed} ->
        conn |> send_resp(401, "")

      {:error, reason} ->
        conn |> send_resp(424, reason)
    end
  end

  defp render_fetch_result(fetch_result, conn, :show) do
    case fetch_result do
      {:ok, %{"content_type" => content_type, "content_length" => content_length}, stream} ->
        case extract_ranges(conn, content_length) do
          {:ok, conn, ranges, is_partial} ->
            conn =
              conn
              |> put_resp_content_type(content_type, nil)
              |> put_resp_header("content-length", "#{ranges |> total_range_length}")
              |> put_resp_header("cache-control", "public, max-age=31536000")
              |> put_resp_header("accept-ranges", "bytes")
              |> send_chunked(
                if is_partial do
                  206
                else
                  200
                end
              )

            # Multiple ranges not yet supported
            [[start_offset, end_offset]] = ranges

            # To deal with the range, we need to create a new stream that either emits or slices chunks
            # so the proper range of bytes is emitted.
            stream
            |> Stream.transform(0, fn chunk, chunk_start ->
              chunk_end = chunk_start + byte_size(chunk) - 1

              cond do
                chunk_end < start_offset ->
                  {[], chunk_end + 1}

                chunk_start <= end_offset ->
                  extract_start =
                    if chunk_start <= start_offset do
                      start_offset - chunk_start
                    else
                      0
                    end

                  extract_end =
                    if chunk_end <= end_offset do
                      chunk_end - chunk_start
                    else
                      end_offset - chunk_start
                    end

                  extract_length = extract_end - extract_start + 1
                  {[binary_part(chunk, extract_start, extract_length)], chunk_end + 1}

                true ->
                  {:halt, chunk_end + 1}
              end
            end)
            |> Stream.map(&chunk(conn, &1))
            |> Stream.run()

            conn
        end

      {:error, :not_found} ->
        conn |> send_resp(400, "")

      {:error, :not_allowed} ->
        conn |> send_resp(401, "")

      {:error, reason} ->
        conn |> send_resp(424, reason)
    end
  end

  defp extract_ranges(conn, content_length) do
    ranges = [[0, content_length - 1]]

    case conn |> get_req_header("range") do
      [<<"bytes=", range::binary>>] ->
        parsed_ranges = range |> ranges_for_range_header(content_length)

        # Multiple ranges not supported yet in chunked responses until we upgrade cowboy, for now just return the whole thing
        if length(parsed_ranges) === 1 do
          conn =
            conn
            |> put_resp_header("content-range", "bytes #{response_ranges_for_ranges(parsed_ranges)}/#{content_length}")

          {:ok, conn, parsed_ranges, true}
        else
          {:ok, conn, ranges, false}
        end

      _ ->
        {:ok, conn, ranges, false}
    end
  end

  defp total_range_length(ranges) do
    # [[100, 200], [300, 400]] -> 200
    ranges |> Enum.reduce(0, fn x, acc -> acc + Enum.at(x, 1) - Enum.at(x, 0) + 1 end)
  end

  defp ranges_for_range_header("-" <> suffix_length, content_length) do
    # "-100", 1000 -> [[899, 999]]

    suffix_length_int = suffix_length |> Integer.parse() |> elem(0)
    [[content_length - suffix_length_int, content_length - 1]]
  end

  defp ranges_for_range_header(range_header, content_length) do
    # "100-200, 300-", 1000 -> [[100, 200], [300, 999]]

    s_to_byte = fn x ->
      if x === "" do
        content_length - 1
      else
        min(content_length - 1, Integer.parse(x) |> elem(0))
      end
    end

    range_header
    |> String.split(", ")
    |> Enum.map(fn x -> String.split(x, "-") |> Enum.map(s_to_byte) end)
  end

  defp response_ranges_for_ranges(ranges) do
    ranges
    |> Enum.map(fn x -> "#{Enum.at(x, 0)}-#{Enum.at(x, 1)}" end)
    |> Enum.join(", ")
  end
end
