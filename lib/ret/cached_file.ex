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
    timestamps()
  end

  # Returns the URI to the file with the given cache key. If file is not
  # cached, expects loader to be a function that returns a %{ path, content_type } map
  # that points to the temporary file whose contents to cache and the content type.
  def fetch(cache_key, loader) do
    Repo.transaction(fn ->
      # Use a PostgreSQL advisory lock on the cache key as a mutex across all
      # nodes for accessing this cache key
      <<lock_key::little-signed-integer-size(64), _::binary>> = :crypto.hash(:sha256, cache_key)

      Ecto.Adapters.SQL.query!(Repo, "select pg_advisory_xact_lock($1);", [lock_key])

      case CachedFile
           |> where(cache_key: ^cache_key)
           |> Repo.one() do
        %CachedFile{file_uuid: file_uuid, file_content_type: file_content_type, file_key: file_key} ->
          Storage.uri_for(file_uuid, file_content_type, file_key)

        nil ->
          %{path: path, content_type: content_type} = loader.()

          file_key = SecureRandom.hex()
          {:ok, file_uuid} = Storage.store(path, content_type, file_key)

          %CachedFile{}
          |> changeset(%{
            cache_key: cache_key,
            file_uuid: file_uuid,
            file_key: file_key,
            file_content_type: content_type
          })
          |> Repo.insert!()

          Storage.uri_for(file_uuid, content_type, file_key)
      end
    end)
  end

  defp changeset(struct, params) do
    struct
    |> cast(params, [:cache_key, :file_uuid, :file_key, :file_content_type])
    |> validate_required([:cache_key, :file_uuid, :file_key, :file_content_type])
    |> unique_constraint(:cache_key)
  end

  def vacuum do
    # Underlying files will be removed by storage vacuum
    one_day_ago = Timex.now() |> Timex.shift(days: -1)

    from(f in CachedFile, where: f.inserted_at() < ^one_day_ago)
    |> Repo.delete_all()
  end
end
