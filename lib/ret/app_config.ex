defmodule Ret.AppConfig do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ret.{AppConfig, Repo, OwnedFile, Storage}

  @schema_prefix "ret0"
  @primary_key {:app_config_id, :id, autogenerate: true}

  # TODO these should be parsed out of schema.toml
  @config_defaults %{
    "features" => %{
      "max_room_size" => 50,
      "default_room_size" => 24
    }
  }

  schema "app_configs" do
    field :key, :string
    field :value, :map

    belongs_to :owned_file, Ret.OwnedFile, references: :owned_file_id

    timestamps()
  end

  def interval, do: :timer.seconds(15)

  def changeset(%AppConfig{} = app_config, key, %OwnedFile{} = owned_file) do
    app_config
    |> cast(%{key: key}, [:key])
    |> put_change(:owned_file_id, owned_file.owned_file_id)
    |> unique_constraint(:key)
  end

  def changeset(%AppConfig{} = app_config, attrs) do
    # We wrap the config value in an outer %{value: ...} map because we want to be able to accept primitive
    # value types, but store them as json.
    attrs = attrs |> Map.put(:value, %{value: attrs.value})

    app_config
    |> cast(attrs, [:key, :value])
    |> unique_constraint(:key)
  end

  def get_config(skip_cache \\ false) do
    result =
      if skip_cache do
        fetch_config("")
      else
        Cachex.fetch(:app_config, "")
      end

    case result do
      {status, config} when status in [:commit, :ok] -> config
    end
  end

  def fetch_config(_arg) do
    config =
      AppConfig
      |> Repo.all()
      |> Repo.preload(:owned_file)
      |> Enum.map(fn app_config -> expand_key(app_config.key, app_config) end)
      |> add_defaults()
      |> Enum.reduce(%{}, fn config, acc -> deep_merge(acc, config) end)

    {:commit, config}
  end

  defp add_defaults(config_entries) do
    [@config_defaults] ++ config_entries
  end

  def collapse(config, parent_key \\ "") do
    case config do
      %{"file_id" => _} -> [{parent_key |> String.trim("|"), config}]
      %{} -> config |> Enum.flat_map(fn {key, val} -> collapse(val, parent_key <> "|" <> key) end)
      _ -> [{parent_key |> String.trim("|"), config}]
    end
  end

  def get_config_value(key) do
    case AppConfig |> Repo.get_by(key: key) do
      %AppConfig{} = app_config ->
        if app_config.value["value"] === "" do
          nil
        else
          app_config.value["value"]
        end

      nil ->
        @config_defaults |> Kernel.get_in(key |> String.split("|"))
    end
  end

  def get_config_bool(key) do
    val = get_config_value(key)
    val !== nil and val
  end

  def get_config_owned_file_uri(key) do
    app_config = AppConfig |> Repo.get_by(key: key) |> Repo.preload(:owned_file)

    with %AppConfig{owned_file: %OwnedFile{} = owned_file} <- app_config do
      owned_file |> OwnedFile.uri_for() |> URI.to_string()
    else
      _ -> nil
    end
  end

  def get_cached_config_value(key), do: get_cached_config_value(key, Mix.env())
  def get_cached_config_owned_file_uri(key), do: get_cached_config_owned_file_uri(key, Mix.env())

  # No caching in test
  def get_cached_config_value(key, :test), do: get_config_value(key)

  def get_cached_config_value(key, _env) do
    case Cachex.fetch(:app_config_value, key) do
      {status, result} when status in [:commit, :ok] -> result
    end
  end

  # No caching in test
  def get_cached_config_owned_file_uri(key, :test), do: get_config_owned_file_uri(key)

  def get_cached_config_owned_file_uri(key, _env) do
    case Cachex.fetch(:app_config_owned_file_uri, key) do
      {status, result} when status in [:commit, :ok] -> result
    end
  end

  def set_config_value(key, value, account \\ nil) do
    app_config = AppConfig |> Repo.get_by(key: key) || %AppConfig{}
    write_config_value(app_config, key, value, account)
  end

  defp write_config_value(
         _app_config,
         _key,
         %{
           "file_id" => _file_id,
           "meta" => %{"access_token" => _access_token, "promotion_token" => _promotion_token}
         },
         nil
       ),
       do: raise(ArgumentError, "Writing file config value requires account")

  defp write_config_value(
         app_config,
         key,
         %{
           "file_id" => file_id,
           "meta" => %{"access_token" => access_token, "promotion_token" => promotion_token}
         },
         account
       ) do
    {:ok, owned_file} = Storage.promote(file_id, access_token, promotion_token, account)
    app_config |> AppConfig.changeset(key, owned_file) |> Repo.insert_or_update!()
  end

  defp write_config_value(app_config, key, value, _account) do
    app_config |> AppConfig.changeset(%{key: key, value: value}) |> Repo.insert_or_update!()
  end

  defp expand_key(key, app_config) do
    if key |> String.contains?("|") do
      [head, tail] = key |> String.split("|", parts: 2)
      %{head => expand_key(tail, app_config)}
    else
      case app_config.owned_file do
        %OwnedFile{} ->
          %{key => app_config.owned_file |> OwnedFile.uri_for() |> URI.to_string()}

        _ ->
          %{
            key =>
              if app_config.value["value"] === "" do
                nil
              else
                app_config.value["value"]
              end
          }
      end
    end
  end

  defp deep_merge(left, right) do
    Map.merge(left, right, &deep_resolve/3)
  end

  defp deep_resolve(_key, left = %{}, right = %{}) do
    deep_merge(left, right)
  end

  defp deep_resolve(_key, _left, right) do
    right
  end
end
