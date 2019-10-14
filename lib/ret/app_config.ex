defmodule Ret.AppConfig do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ret.{AppConfig, Repo}

  @schema_prefix "ret0"
  @primary_key {:app_config_id, :id, autogenerate: true}

  schema "app_configs" do
    field(:key, :string)
    field(:value, :string)
    belongs_to(:owned_file, Ret.OwnedFile, references: :owned_file_id)
    timestamps()
  end

  def changeset(%AppConfig{} = app_config, attrs) do
    app_config
    |> cast(attrs, [:key, :value])
    |> unique_constraint(:value)
  end

  def get_config() do
    AppConfig |> Repo.all() |> Map.new(&{&1.key, &1.value})
  end
end
