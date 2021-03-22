defmodule Ret.CachedFile do
  require Logger
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset
  alias Ret.{Repo, CachedFile, Storage}

  @schema_prefix "ret0"
  @primary_key {:cached_file_id, :id, autogenerate: true}

  schema "cached_files" do
    field(:cache_key, :string)
    field(:file_uuid, :string)
    field(:file_key, :string)
    field(:file_content_type, :string)
    field(:accessed_at, :naive_datetime)
    timestamps()
  end

  # Returns the URI to the file with the given cache key. If file is not
  # cached, expects loader to be a function that will receive a path to a temp file to
  # write the data to cache to, and is expected to return a { :ok, %{ content_type: } } tuple
  # with the content type.
  def fetch(cache_key, loader) do
    # Use a PostgreSQL advisory lock on the cache key as a mutex across all
    # nodes for accessing this cache key
    Ret.Locking.exec_after_lock(cache_key, fn ->
      case CachedFile |> where(cache_key: ^cache_key) |> Repo.one() do
        %CachedFile{file_uuid: file_uuid, file_content_type: file_content_type, file_key: file_key} ->
          Storage.uri_for(file_uuid, file_content_type, file_key)

        nil ->
          load_and_store(%{cache_key: cache_key, loader: loader})
      end
    end)
  end

  defp load_and_store(%{cache_key: cache_key, loader: loader}) do
    {:ok, path} = Temp.path()
    file_key = SecureRandom.hex()

    try do
      with {:ok, %{content_type: content_type}} <- loader.(path),
           {:ok, file_uuid} <-
             Storage.store(path, content_type, file_key, nil, Storage.cached_file_path()),
           {:ok, _} <-
             %CachedFile{}
             |> changeset(%{
               cache_key: cache_key,
               file_uuid: file_uuid,
               file_key: file_key,
               file_content_type: content_type,
               accessed_at: Timex.now() |> Timex.to_naive_datetime() |> NaiveDateTime.truncate(:second)
             })
             |> Repo.insert() do
        Storage.uri_for(file_uuid, content_type, file_key)
      else
        :error ->
          {:error, "error loading or storing asset"}

        {:error, reason} ->
          {:error, "error loading or storing asset. #{reason}"}
      end
    after
      File.rm_rf(path)
    end
  end

  defp changeset(struct, params) do
    struct
    |> cast(params, [:cache_key, :file_uuid, :file_key, :file_content_type, :accessed_at])
    |> validate_required([:cache_key, :file_uuid, :file_key, :file_content_type, :accessed_at])
    |> unique_constraint(:cache_key)
  end

  def vacuum do
    # TODO: Hubs Cloud must migrate underlying files to the cached_file_path() or else purge
    # CachedFile records that point to files from the expiring_file_path() that have been vacuumed
    expiration = Timex.now() |> Timex.shift(weeks: -2) |> Timex.to_naive_datetime()
    vacuum(%{expiration: expiration})
  end

  def vacuum(%{expiration: expiration}) do
    Ret.Locking.exec_if_lockable(:cached_file_vacuum, fn ->
      cached_files_to_delete = from(f in CachedFile, where: f.accessed_at() < ^expiration) |> Repo.all()
      keys = Enum.map(cached_files_to_delete, fn v -> v.cache_key end)

      case Storage.vacuum(%{cached_files: cached_files_to_delete}) do
        {:ok, %{vacuumed: vacuumed, errors: []}} ->
          Repo.delete_all(from(c in CachedFile, where: c.cache_key in ^keys))
          %{vacuumed: vacuumed, errors: []}

        {:ok, %{vacuumed: vacuumed, errors: errors}} ->
          Repo.delete_all(from(c in CachedFile, where: c.cache_key in ^keys))
          # If a CachedFile is backed by a file in expiring_storage_path, then this version of
          # the Storage.vacuum task will not delete the underlying files.
          Logger.info("Removing #{length(errors)} cached files without finding underlying assets.")
          %{vacuumed: vacuumed, errors: errors}

        _ ->
          Logger.info("Failed to vacuum cached files. #{length(cached_files_to_delete)} files will not be deleted.")
          %{vacuumed: [], errors: cached_files_to_delete}
      end
    end)
  end
end
