defmodule Ret.StoredFiles do
  require Logger

  @chunk_size 1024 * 1024

  # Given a Plug.Upload, a content-type, and an optional encryption key, returns an id
  # that can be used to fetch a stream to the uploaded file after this call.
  def store(%Plug.Upload{path: path}, content_type, key) do
    with storage_path when is_binary(storage_path) <- module_config(:storage_path) do
      {:ok, %{size: content_length}} = File.stat(path)
      uuid = Ecto.UUID.generate()

      [file_path, meta_file_path, blob_file_path] = paths_for_uuid(uuid)
      File.mkdir_p!(file_path)

      case write_blob_file(path, blob_file_path, key) do
        :ok ->
          meta = %{
            content_type: content_type,
            content_length: content_length,
            blob: blob_file_path,
            encrypted: key != nil
          }

          meta_file_path |> File.write!(Poison.encode!(meta))

          {:ok, uuid}

        {:error, _reason} = err ->
          err
      end
    else
      _ -> {:error, :not_allowed}
    end
  end

  def fetch(id, key) do
    with storage_path when is_binary(storage_path) <- module_config(:storage_path) do
      case Ecto.UUID.cast(id) do
        {:ok, uuid} ->
          [_file_path, meta_file_path, blob_file_path] = paths_for_uuid(uuid)

          case [File.stat(meta_file_path), File.stat(blob_file_path)] do
            [{:ok, _stat}, {:ok, _blob_stat}] ->
              meta = File.read!(meta_file_path) |> Poison.decode!()

              case read_blob_file(blob_file_path, meta, key) do
                {:ok, stream} -> {:ok, meta, stream}
                {:error, :invalid_key} -> {:error, :not_allowed}
                _ -> {:error, :not_found}
              end

            _ ->
              {:error, :not_found}
          end

        :error ->
          {:error, :not_found}
      end
    else
      _ -> {:error, :not_allowed}
    end
  end

  # Vacuums up TTLed out files
  def vacuum do
    Logger.info("Stored Files: Beginning Vacuum.")

    with storage_path when is_binary(storage_path) <- module_config(:storage_path),
         ttl when is_integer(ttl) <- module_config(:ttl) do
      process_meta = fn meta_file, _acc ->
        meta = File.read!(meta_file) |> Poison.decode!()
        blob_file = meta["blob"]

        {:ok, %{atime: atime}} = File.stat(blob_file)

        now = DateTime.utc_now()
        atime_datetime = atime |> NaiveDateTime.from_erl!() |> DateTime.from_naive!("Etc/UTC")
        seconds_since_access = DateTime.diff(now, atime_datetime)

        if seconds_since_access > ttl do
          Logger.info(
            "Stored Files: Removing #{blob_file} after #{seconds_since_access}s since last access."
          )

          File.rm!(blob_file)
          File.rm!(meta_file)
        end
      end

      :filelib.fold_files(
        "#{storage_path}/expiring",
        "\\.meta\\.json$",
        true,
        process_meta,
        nil
      )
    end

    Logger.info("Stored Files: Vacuum Finished.")
  end

  defp read_blob_file(_source_path, %{"encrypted" => true}, nil) do
    {:error, :invalid_key}
  end

  defp read_blob_file(source_path, %{"encrypted" => false}, _key) do
    {:ok, File.stream!(source_path, [], @chunk_size)}
  end

  defp read_blob_file(source_path, _meta, key) do
    Ret.Crypto.stream_decrypt_file(source_path, key)
  end

  defp write_blob_file(source_path, destination_path, nil) do
    File.cp!(source_path, destination_path)
  end

  defp write_blob_file(source_path, destination_path, key) do
    Ret.Crypto.encrypt_file(source_path, destination_path, key)
  end

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end

  defp paths_for_uuid(uuid) do
    path =
      "#{module_config(:storage_path)}/expiring/#{String.slice(uuid, 0, 2)}/#{
        String.slice(uuid, 2, 2)
      }"

    blob_file_path = "#{path}/#{uuid}.blob"
    meta_file_path = "#{path}/#{uuid}.meta.json"

    [path, meta_file_path, blob_file_path]
  end
end
