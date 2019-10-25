defmodule Ret.AppConfig do
  use Cachex.Warmer
  use Ecto.Schema
  import Ecto.Changeset

  alias Ret.{AppConfig, Repo}

  @schema_prefix "ret0"
  @primary_key {:app_config_id, :id, autogenerate: true}

  schema "app_configs" do
    field(:key, :string)
    field(:value, :map)
    belongs_to(:owned_file, Ret.OwnedFile, references: :owned_file_id)
    timestamps()
  end

  def interval, do: :timer.seconds(15)

  def execute(_state) do
    {:ok, [{:app_config, get_config()}]}
  end

  def changeset(%AppConfig{} = app_config, attrs) do
    # We wrap the config value in an outer %{value: ...} map because we want to be able to accept primitive
    # value types, but store them as json.
    attrs = attrs |> Map.put("value", %{value: attrs["value"]})

    app_config
    |> cast(attrs, [:key, :value])
    |> unique_constraint(:key)
  end

  def get_config() do
    AppConfig
    |> Repo.all()
    |> Enum.map(fn app_config -> expand_key(app_config.key, app_config.value["value"]) end)
    |> Enum.reduce(%{}, fn config, acc -> deep_merge(acc, config) end)
  end

  defp expand_key(key, val) do
    if key |> String.contains?("|") do
      [head, tail] = key |> String.split("|", parts: 2)
      %{head => expand_key(tail, val)}
    else
      %{key => val}
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

  def collapse(config, parent_key \\ "") do
    case config do
      %{} -> config |> Enum.flat_map(fn {key, val} -> collapse(val, parent_key <> "|" <> key) end)
      _ -> [{parent_key |> String.trim("|"), config}]
    end
  end
end
