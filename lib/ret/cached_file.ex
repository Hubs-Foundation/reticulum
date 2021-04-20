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
  # cached, expects loader to be a function that will receive a path to a temp file to
  # write the data to cache to, and is expected to return a { :ok, %{ content_type: } } tuple
  # with the content type.
  def fetch(cache_key, loader) do
    # Use a PostgreSQL advisory lock on the cache key as a mutex across all
    # nodes for accessing this cache key
    #
    Ret.Locking.exec_after_lock(cache_key, fn ->
      case CachedFile
           |> where(cache_key: ^cache_key)
           |> Repo.one() do
        %CachedFile{file_uuid: file_uuid, file_content_type: file_content_type, file_key: file_key} ->
          Storage.uri_for(file_uuid, file_content_type, file_key)

        nil ->
          {:ok, path} = Temp.path()

          try do
            loader_result = loader.(path)

            case loader_result do
              {:ok, %{content_type: content_type}} ->
                file_key = SecureRandom.hex()

                case Storage.store(path, content_type, file_key) do
                  {:ok, file_uuid} ->
                    %CachedFile{}
                    |> changeset(%{
                      cache_key: cache_key,
                      file_uuid: file_uuid,
                      file_key: file_key,
                      file_content_type: content_type
                    })
                    |> Repo.insert!()

                    Storage.uri_for(file_uuid, content_type, file_key)

                  {:error, reason} ->
                    {:error, "error running loader: #{reason}"}
                end

              :error ->
                {:error, "error running loader"}
            end
          after
            File.rm_rf(path)
          end
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
    Ret.Locking.exec_if_lockable(:cached_file_vacuum, fn ->
      # Underlying files will be removed by storage vacuum
      two_days_ago = Timex.now() |> Timex.shift(days: -2)

      from(f in CachedFile, where: f.inserted_at() < ^two_days_ago)
      |> Repo.delete_all()
    end)
  end
end
