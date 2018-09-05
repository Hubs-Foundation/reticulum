defmodule Ret.StoredFiles do
  require Logger

  @expiring_file_path "expiring"
  @stored_file_path "stored"

  alias Ret.{StoredFile, Repo, Account}

  # Given a Plug.Upload, a content-type, and an optional encryption key, returns an id
  # that can be used to fetch a stream to the uploaded file after this call.
  def store(%Plug.Upload{path: path}, content_type, key) do
    with storage_path when is_binary(storage_path) <- module_config(:storage_path) do
      {:ok, %{size: content_length}} = File.stat(path)
      uuid = Ecto.UUID.generate()

      [file_path, meta_file_path, blob_file_path] = paths_for_uuid(uuid, @expiring_file_path)
      File.mkdir_p!(file_path)

      case write_blob_file(path, blob_file_path, key) do
        :ok ->
          meta = %{
            content_type: content_type,
            content_length: content_length
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

  def fetch(id, key) when is_binary(id) and is_binary(key) do
    fetch_blob(id, key, @expiring_file_path)
  end

  def fetch(%StoredFile{stored_file_sid: id, key: key}) do
    fetch_blob(id, key, @stored_file_path)
  end

  defp fetch_blob(id, key, subpath) do
    with storage_path when is_binary(storage_path) <- module_config(:storage_path) do
      case Ecto.UUID.cast(id) do
        {:ok, uuid} ->
          [_file_path, meta_file_path, blob_file_path] = paths_for_uuid(uuid, subpath)

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

  # Promotes multiple files into the given account.
  #
  # Given a map that has { id, key } tuple values, returns a similarly-keyed map
  # that has StoredFiles as values.
  def promote_multi(map, %Account{} = account) when is_map(map) do
    stored_files = map
    |> Enum.map(fn {k, {id, key}} ->
      {:ok, stored_file} = promote(id, key, account)
      {k, stored_file}
    end)
    |> Enum.into(%{})

    { :ok, stored_files }
  end

  # Promotes an expiring stored file to a permanently stored file in the specified Account.
  def promote(id, key, %Account{} = account) do
    # Check if this file has already been promoted
    StoredFile
    |> Repo.get_by(stored_file_sid: id)
    |> promote_or_return_stored_file(id, key, account)
  end

  defp promote_or_return_stored_file(%StoredFile{} = stored_file, _id, _key, _account) do
    {:ok, stored_file}
  end

  defp promote_or_return_stored_file(nil, id, key, account) do
    with storage_path when is_binary(storage_path) <- module_config(:storage_path) do
      case Ecto.UUID.cast(id) do
        {:ok, uuid} ->
          [_, meta_file_path, blob_file_path] = paths_for_uuid(uuid, @expiring_file_path)

          [dest_path, dest_meta_file_path, dest_blob_file_path] =
            paths_for_uuid(uuid, @stored_file_path)

          case [File.stat(meta_file_path), File.stat(blob_file_path)] do
            [{:ok, _stat}, {:ok, _blob_stat}] ->
              case check_blob_file_key(blob_file_path, key) do
                {:ok} ->
                  %{"content_type" => content_type, "content_length" => content_length} =
                    File.read!(meta_file_path) |> Poison.decode!()

                  stored_file_params = %{
                    stored_file_sid: id,
                    key: key,
                    content_type: content_type,
                    content_length: content_length
                  }

                  stored_file =
                    %StoredFile{}
                    |> StoredFile.changeset(account, stored_file_params)
                    |> Repo.insert!()

                  File.mkdir_p!(dest_path)
                  File.rename(meta_file_path, dest_meta_file_path)
                  File.rename(blob_file_path, dest_blob_file_path)

                  {:ok, stored_file}

                {:error, :invalid_key} ->
                  {:error, :not_allowed}

                _ ->
                  {:error, :not_found}
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
      process_blob = fn blob_file, _acc ->
        {:ok, %{atime: atime}} = File.stat(blob_file)

        now = DateTime.utc_now()
        atime_datetime = atime |> NaiveDateTime.from_erl!() |> DateTime.from_naive!("Etc/UTC")
        seconds_since_access = DateTime.diff(now, atime_datetime)

        if seconds_since_access > ttl do
          Logger.info(
            "Stored Files: Removing #{blob_file} after #{seconds_since_access}s since last access."
          )

          File.rm!(blob_file)
          File.rm(blob_file |> String.replace_suffix(".blob", ".meta.json"))
        end
      end

      :filelib.fold_files(
        "#{storage_path}/#{@expiring_file_path}",
        "\\.blob$",
        true,
        process_blob,
        nil
      )

      # TODO clean empty dirs
    end

    Logger.info("Stored Files: Vacuum Finished.")
  end

  defp check_blob_file_key(source_path, key) do
    Ret.Crypto.stream_check_key(source_path, key |> Ret.Crypto.hash())
  end

  defp read_blob_file(source_path, _meta, key) do
    Ret.Crypto.stream_decrypt_file(source_path, key |> Ret.Crypto.hash())
  end

  defp write_blob_file(source_path, destination_path, key) do
    Ret.Crypto.encrypt_file(source_path, destination_path, key |> Ret.Crypto.hash())
  end

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end

  defp paths_for_uuid(uuid, subpath) do
    path =
      "#{module_config(:storage_path)}/#{subpath}/#{String.slice(uuid, 0, 2)}/#{
        String.slice(uuid, 2, 2)
      }"

    blob_file_path = "#{path}/#{uuid}.blob"
    meta_file_path = "#{path}/#{uuid}.meta.json"

    [path, meta_file_path, blob_file_path]
  end
end
