defmodule Ret.Storage do
  require Logger

  import Ret.HttpUtils

  def expiring_file_path, do: "expiring"
  def owned_file_path, do: "owned"
  def cached_file_path, do: "cached"

  @chunk_size 1024 * 1024

  alias Ret.{OwnedFile, CachedFile, Repo, Account}

  def store(path, content_type, key, promotion_token \\ nil)

  # Given a Plug.Upload, a content-type, and an optional encryption key, returns an id
  # that can be used to fetch a stream to the uploaded file after this call.
  def store(%Plug.Upload{path: path}, content_type, key, promotion_token) do
    store(path, content_type, key, promotion_token)
  end

  def store(path, content_type, key, promotion_token) do
    store(
      path,
      content_type,
      key,
      promotion_token,
      expiring_file_path()
    )
  end

  # Given a path to a file, a content-type, and an optional encryption key, returns an id
  # that can be used to fetch a stream to the uploaded file after this call.
  def store(path, content_type, key, promotion_token, file_path) do
    if in_quota?() do
      case File.stat(path) do
        {:ok, %{size: source_size}} ->
          source_stream = path |> File.stream!([], @chunk_size)
          store_stream(source_stream, source_size, content_type, key, promotion_token, file_path)

        {:error, _reason} = err ->
          err
      end
    else
      {:error, :quota}
    end
  end

  # Given a stream, a content-type, an optional encryption key, and a storage subpath, returns an id
  # that can be used to fetch a stream to the uploaded file after this call.
  def store_stream(source_stream, source_size, content_type, key, promotion_token, subpath) do
    with storage_path when is_binary(storage_path) <- module_config(:storage_path) do
      uuid = Ecto.UUID.generate()
      [file_directory, meta_file_path, blob_file_path] = paths_for_uuid(uuid, subpath)

      File.mkdir_p!(file_directory)
      source_stream |> encrypt_stream_to_file(source_size, blob_file_path, key)

      meta_file_path
      |> File.write!(
        Poison.encode!(%{
          content_type: content_type,
          content_length: source_size,
          promotion_token: promotion_token
        })
      )

      {:ok, uuid}
    else
      _ -> {:error, :not_allowed}
    end
  end

  def fetch(id, key) when is_binary(id) and is_binary(key) do
    fetch_blob(id, key, expiring_file_path())
  end

  # TODO: Should this function not exist because it is only used in testing?
  def fetch(id, key, file_path) when is_binary(id) and is_binary(key) do
    fetch_blob(id, key, file_path)
  end

  def fetch(%OwnedFile{owned_file_uuid: id, key: key}) do
    fetch_blob(id, key, owned_file_path())
  end

  def fetch(%CachedFile{} = cached_file) do
    fetch_at(cached_file, Timex.now() |> Timex.to_naive_datetime() |> NaiveDateTime.truncate(:second))
  end

  defp maybe_bump_accessed_at(%CachedFile{accessed_at: accessed_at} = cached_file, time) do
    one_day_ago = Timex.shift(time, days: -1)

    # Save a trip to the database if this file was recently accessed.
    # If the vacuum window for CachedFiles is on the order of days, only update
    # the accessed_at time daily. If vacuuming happens on the order of weeks,
    # we can update accessed_at even less often. This is a minor (perhaps unnecessary)
    # performance optimization.
    if Timex.before?(accessed_at, one_day_ago) do
      cached_file |> Ecto.Changeset.change(accessed_at: time) |> Ret.Repo.update()
    end
  end

  defp lock_and_migrate(%CachedFile{file_uuid: id, file_key: key} = cached_file) do
    Ret.Locking.exec_after_lock(
      "migrate_" <> id,
      fn ->
        # Try fetch_blob again in case the file has been migrated
        # while waiting for the lock
        case fetch_blob(id, key, cached_file_path()) do
          {:ok, meta, stream} ->
            {:ok, meta, stream}

          {:error, _} ->
            migrate(cached_file)
        end
      end
    )
  end

  def fetch_at(%CachedFile{file_uuid: id, file_key: key} = cached_file, time) do
    maybe_bump_accessed_at(cached_file, time)

    case fetch_blob(id, key, cached_file_path()) do
      {:ok, meta, stream} ->
        {:ok, meta, stream}

      {:error, _} ->
        case lock_and_migrate(cached_file) do
          {:ok, {:ok, meta, stream}} ->
            # Got lock, but file had already been migrated
            {:ok, meta, stream}

          {:ok, {:ok, _cached_file}} ->
            # Got lock, then migrated
            fetch_blob(id, key, cached_file_path())

          {:ok, {:error, reason}} ->
            # Got lock, failed to migrate the file
            {:error, reason}

          _ ->
            {:error, "Failed to acquire database lock."}
        end
    end
  end

  # TODO: Remove this code once all the CachedFiles are stored in the cached_file_path().
  defp migrate(%CachedFile{file_uuid: id, file_key: file_key} = cached_file) do
    with {:ok, _meta, _stream} <- fetch_blob(id, file_key, expiring_file_path()),
         {:ok, uuid} <- Ecto.UUID.cast(id),
         [_src_file_directory, src_meta_file_path, src_blob_file_path] <- paths_for_uuid(uuid, expiring_file_path()),
         [dest_file_directory, dest_meta_file_path, dest_blob_file_path] <- paths_for_uuid(uuid, cached_file_path()),
         :ok <- File.mkdir_p(dest_file_directory),
         :ok <- File.cp(src_meta_file_path, dest_meta_file_path),
         :ok <- File.cp(src_blob_file_path, dest_blob_file_path) do
      {:ok, cached_file}
    else
      {:error, reason} -> {:error, "Migration failed: #{reason}"}
      _ -> {:error, "Migration failed"}
    end
  end

  defp fetch_blob(id, key, subpath) do
    with storage_path when is_binary(storage_path) <- module_config(:storage_path),
         {:ok, uuid} <- Ecto.UUID.cast(id),
         [_file_path, meta_file_path, blob_file_path] <- paths_for_uuid(uuid, subpath),
         {:ok, _} <- File.stat(meta_file_path),
         {:ok, _} <- File.stat(blob_file_path),
         {:ok, meta_file_data} <- File.read(meta_file_path),
         {:ok, meta} <- Poison.decode(meta_file_data),
         {:ok, stream} <- decrypt_file_to_stream(blob_file_path, meta, key) do
      {:ok, meta, stream}
    else
      {:error, :invalid_key} -> {:error, :not_allowed}
      {:error, :enoent} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
      _ -> {:error, :not_allowed}
    end
  end

  def promote(nil, _key, _promotion_token, _account) do
    {:error, :not_found}
  end

  def promote(_id, nil, _promotion_token, _account) do
    {:error, :not_allowed}
  end

  # Promotes an expiring stored file to a permanently stored file in the specified Account.
  def promote(id, key, promotion_token, %Account{} = account) do
    # Check if this file has already been promoted
    OwnedFile
    |> Repo.get_by(owned_file_uuid: id)
    |> promote_or_return_owned_file(id, key, promotion_token, account)
  end

  # Promotes multiple files into the given account.
  #
  # Given a map that has { id, key } or { id, key, promotion_token} tuple values, returns a similarly-keyed map
  # that has the return values of promote as values.
  def promote(map, %Account{} = account) when is_map(map) do
    map
    |> Enum.map(fn
      {k, {id, key}} -> {k, promote(id, key, nil, account)}
      {k, {id, key, promotion_token}} -> {k, promote(id, key, promotion_token, account)}
    end)
    |> Enum.into(%{})
  end

  # Similar to promote above, but allows for passing nil. Useful for optional upload fields
  def promote_optional(map, %Account{} = account) when is_map(map) do
    map
    |> Enum.map(fn
      {k, {nil, nil}} -> {k, {:ok, nil}}
      {k, {nil, nil, nil}} -> {k, {:ok, nil}}
      {k, {id, key}} -> {k, promote(id, key, nil, account)}
      {k, {id, key, promotion_token}} -> {k, promote(id, key, promotion_token, account)}
    end)
    |> Enum.into(%{})
  end

  defp promote_or_return_owned_file(%OwnedFile{} = owned_file, _id, _key, _promotion_token, _account) do
    {:ok, owned_file}
  end

  # Promoting a stored file to being owned has two side effects: the file is moved
  # into the owned files directory (which prevents it from being vacuumed) and an
  # OwnedFile record is inserted into the database which includes the decryption key.
  # If the stored file has an associated promotion token, the given promotion token is verified against it.
  # If the given promotion token fails verification, the file is not promoted.
  defp promote_or_return_owned_file(nil, id, key, promotion_token, account) do
    with(
      storage_path when is_binary(storage_path) <- module_config(:storage_path),
      {:ok, uuid} <- Ecto.UUID.cast(id),
      [_, meta_file_path, blob_file_path] <- paths_for_uuid(uuid, expiring_file_path()),
      [dest_path, dest_meta_file_path, dest_blob_file_path] <- paths_for_uuid(uuid, owned_file_path()),
      [{:ok, _}, {:ok, _}] <- [File.stat(meta_file_path), File.stat(blob_file_path)],
      %{"content_type" => content_type, "content_length" => content_length, "promotion_token" => actual_promotion_token} <-
        File.read!(meta_file_path) |> Poison.decode!(),
      {:ok} <- check_promotion_token(actual_promotion_token, promotion_token),
      {:ok} <- check_blob_file_key(blob_file_path, key)
    ) do
      owned_file_params = %{
        owned_file_uuid: id,
        key: key,
        content_type: content_type,
        content_length: content_length
      }

      owned_file =
        %OwnedFile{}
        |> OwnedFile.changeset(account, owned_file_params)
        |> Repo.insert!()

      File.mkdir_p!(dest_path)
      File.rename(meta_file_path, dest_meta_file_path)
      File.rename(blob_file_path, dest_blob_file_path)

      {:ok, owned_file}
    else
      {:error, :invalid_key} -> {:error, :not_allowed}
      _ -> {:error, :not_found}
    end
  end

  # If an owned file does not have a promotion token associated with it, it can be promoted with any given 
  # promotion token, including nil.
  defp check_promotion_token(nil, _token), do: {:ok}
  defp check_promotion_token(actual_token, token) when actual_token == token, do: {:ok}
  defp check_promotion_token(actual_token, token) when actual_token != token, do: {:error, :invalid_key}

  # Vacuums up TTLed out files
  def vacuum do
    Logger.info("Stored Files: Attempting Vacuum.")

    Ret.Locking.exec_if_lockable(:storage_vacuum, fn ->
      Logger.info("Stored Files: Beginning Vacuum.")

      with storage_path when is_binary(storage_path) <- module_config(:storage_path),
           ttl when is_integer(ttl) <- module_config(:ttl) do
        process_blob = fn blob_file, _acc ->
          {:ok, %{atime: atime}} = File.stat(blob_file)

          now = DateTime.utc_now()
          atime_datetime = atime |> NaiveDateTime.from_erl!() |> DateTime.from_naive!("Etc/UTC")
          seconds_since_access = DateTime.diff(now, atime_datetime)

          if seconds_since_access > ttl do
            Logger.info("Stored Files: Removing #{blob_file} after #{seconds_since_access}s since last access.")

            File.rm!(blob_file)
            File.rm(blob_file |> String.replace_suffix(".blob", ".meta.json"))
          end
        end

        :filelib.fold_files(
          Path.join(storage_path, expiring_file_path()),
          "\\.blob$",
          true,
          process_blob,
          nil
        )

        # TODO figure out what to do about owned files -- that structure increase over time
        root_path = "#{storage_path}/#{expiring_file_path()}"
        clean_empty_dirs(root_path)
      end

      Logger.info("Stored Files: Vacuum Finished.")
    end)
  end

  defp remove_underlying_assets(%{cached_file: %CachedFile{file_uuid: id} = cached_file, path: path}) do
    try do
      {:ok, uuid} = Ecto.UUID.cast(id)
      [_file_path, meta_file_path, blob_file_path] = paths_for_uuid(uuid, path)
      File.rm!(blob_file_path)
      File.rm!(meta_file_path)
      {:ok, cached_file}
    rescue
      _ ->
        {:error, "Failed to remove underlying assets for cached file.", cached_file}
    end
  end

  def vacuum(%{cached_files: cached_files}) do
    Logger.info("Stored Files: Attempting Vacuum.")

    Ret.Locking.exec_if_lockable(:storage_vacuum, fn ->
      Logger.info("Stored Files: Beginning Vacuum.")

      results =
        with storage_path when is_binary(storage_path) <- module_config(:storage_path) do
          results =
            cached_files
            |> Enum.map(fn cached_file ->
              remove_underlying_assets(%{
                cached_file: cached_file,
                path: cached_file_path()
              })
            end)
            |> Enum.reduce(%{vacuumed: [], errors: []}, fn
              {:ok, cached_file}, %{vacuumed: vacuumed, errors: errors} ->
                %{vacuumed: vacuumed ++ [cached_file], errors: errors}

              {:error, _, cached_file}, %{vacuumed: vacuumed, errors: errors} ->
                %{vacuumed: vacuumed, errors: errors ++ [cached_file]}
            end)

          root_path = "#{storage_path}/#{cached_file_path()}"
          clean_empty_dirs(root_path)
          results
        end

      Logger.info("Stored Files: Vacuum Finished.")

      results
    end)
  end

  defp clean_empty_dirs(root_path) do
    with {:ok, dirs} <- :file.list_dir(root_path) do
      # Walk sub directories and remove them if they are empty.
      for d <- dirs do
        sub_path = Path.join(root_path, d)

        with {:ok, subdirs} <- :file.list_dir(sub_path) do
          for sd <- subdirs do
            path = Path.join(sub_path, sd)

            with {:ok, files} <- :file.list_dir(path) do
              if files |> length === 0 do
                File.rmdir(path)
              end
            end
          end
        end
      end

      # Check if we've removed all the sub directories.
      for d <- dirs do
        sub_path = Path.join(root_path, d)

        with {:ok, subdirs} <- :file.list_dir(sub_path) do
          if subdirs |> length === 0 do
            File.rmdir(sub_path)
          end
        end
      end
    end
  end

  def demote_inactive_owned_files do
    Ret.Locking.exec_if_lockable(:storage_demote, fn ->
      inactive_owned_files = OwnedFile.inactive()

      inactive_owned_files
      |> Enum.map(& &1.owned_file_uuid)
      |> Enum.each(&move_file_to_expiring_storage/1)

      inactive_owned_files
      |> Enum.each(&Repo.delete/1)
    end)
  end

  defp move_file_to_expiring_storage(uuid) do
    with(
      [_, meta_file_path, blob_file_path] <- paths_for_uuid(uuid, owned_file_path()),
      [dest_path, dest_meta_file_path, dest_blob_file_path] <- paths_for_uuid(uuid, expiring_file_path())
    ) do
      File.mkdir_p!(dest_path)
      File.rename(meta_file_path, dest_meta_file_path)
      File.rename(blob_file_path, dest_blob_file_path)
    end
  end

  def uri_for(id, content_type, token \\ nil) do
    file_host = Application.get_env(:ret, Ret.Storage)[:host] || RetWeb.Endpoint.url()
    ext = MIME.extensions(content_type) |> List.first()
    filename = [id, ext] |> Enum.reject(&is_nil/1) |> Enum.join(".")

    "#{file_host}/files/#{filename}#{
      if token do
        "?" <> URI.encode_query(token: token)
      else
        ""
      end
    }"
    |> URI.parse()
  end

  defp check_blob_file_key(_source_path, nil) do
    {:error, :invalid_key}
  end

  defp check_blob_file_key(source_path, key) do
    Ret.Crypto.stream_check_key(source_path, key |> Ret.Crypto.hash())
  end

  defp decrypt_file_to_stream(source_path, _meta, key) do
    Ret.Crypto.decrypt_file_to_stream(source_path, key |> Ret.Crypto.hash())
  end

  defp encrypt_stream_to_file(source_stream, source_size, destination_path, key) do
    Ret.Crypto.encrypt_stream_to_file(source_stream, source_size, destination_path, key |> Ret.Crypto.hash())
  end

  defp paths_for_uuid(uuid, subpath) do
    path = "#{module_config(:storage_path)}/#{subpath}/#{String.slice(uuid, 0, 2)}/#{String.slice(uuid, 2, 2)}"

    blob_file_path = "#{path}/#{uuid}.blob"
    meta_file_path = "#{path}/#{uuid}.meta.json"

    [path, meta_file_path, blob_file_path]
  end

  def duplicate(%OwnedFile{owned_file_uuid: id, key: key}, %Account{} = account) do
    {:ok,
     %{
       "content_type" => content_type,
       "content_length" => content_length
     }, source_stream} = fetch_blob(id, key, owned_file_path())

    new_key = SecureRandom.hex()
    new_promotion_token = SecureRandom.hex()

    {:ok, new_id} =
      store_stream(source_stream, content_length, content_type, new_key, new_promotion_token, owned_file_path())

    owned_file_params = %{
      owned_file_uuid: new_id,
      key: new_key,
      content_type: content_type,
      content_length: content_length
    }

    owned_file =
      %OwnedFile{}
      |> OwnedFile.changeset(account, owned_file_params)
      |> Repo.insert!()

    {:ok, owned_file}
  end

  defp download!(url) do
    {:ok, content_type} = fetch_content_type(url)
    {:ok, download_path} = Temp.path()

    case Download.from(url, path: download_path) do
      {:ok, _path} ->
        {download_path, content_type}

      _error ->
        throw("Error downloading #{url}")
    end
  end

  def owned_files_from_urls!(urls, account) do
    urls
    |> Enum.map(&download!/1)
    |> Enum.map(fn {download_path, content_type} ->
      access_token = SecureRandom.hex()
      promotion_token = SecureRandom.hex()

      {:ok, file_uuid} = store(download_path, content_type, access_token, promotion_token)
      {file_uuid, access_token, promotion_token}

      {:ok, owned_file} = promote(file_uuid, access_token, promotion_token, account)

      owned_file
    end)
  end

  def in_quota?() do
    with storage_path when is_binary(storage_path) <- module_config(:storage_path),
         quota_gb when is_integer(quota_gb) and quota_gb > 0 <- module_config(:quota_gb) do
      case Cachex.get(:storage_used, :storage_used) do
        {:ok, 0} -> true
        {:ok, kbytes} -> kbytes < quota_gb * 1024 * 1024
        _ -> false
      end
    else
      _ -> true
    end
  end

  defp module_config(key), do: Application.get_env(:ret, __MODULE__)[key]
end
