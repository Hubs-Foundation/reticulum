defmodule Ret.CachedFile do
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

  def fetch(cache_key, loader) do
    fetch(%{cache_key: cache_key, loader: loader})
  end

  # Returns the URI to the file with the given cache key. If file is not
  # cached, expects loader to be a function that will receive a path to a temp file to
  # write the data to cache to, and is expected to return a { :ok, %{ content_type: } } tuple
  # with the content type.
  def fetch(%{cache_key: cache_key, loader: loader}) do
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
             Storage.store(%{
               path: path,
               content_type: content_type,
               key: file_key,
               promotion_token: nil,
               file_path: Storage.cached_file_path()
             }),
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
    now = Timex.now()
    expiration = Timex.shift(now, weeks: -4)
    vacuum(%{expiration: expiration})
  end

  def vacuum(%{expiration: expiration}) do
    Ret.Locking.exec_if_lockable(:cached_file_vacuum, fn ->
      cached_files_to_delete = from(f in CachedFile, where: f.accessed_at() < ^expiration) |> Repo.all()

      case Storage.vacuum(%{cached_files: cached_files_to_delete}) do
        {:ok, %{vacuumed: vacuumed, errors: _errors}} ->
          vacuumed |> Enum.each(&Repo.delete/1)

        # TODO: What if some failed to be vacuumed?

        _ ->
          # TODO: What to do if storage vacuum fails?
          nil
      end
    end)
  end
end
