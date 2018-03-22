defmodule Ret.Hub do
  use Ecto.Schema
  import Ecto.Changeset
  alias Ret.Hub

  @schema_prefix "ret0"
  @primary_key { :hub_id, :integer, [] }

  schema "hubs" do
    field :hub_sid, :string
    field :default_scene_url, :string

    timestamps()
  end

  @doc false
  def changeset(%Hub{} = hub, attrs) do
    hub
    |> cast(attrs, [:hub_sid, :default_scene_url])
    |> validate_required([:hub_sid, :default_scene_url])
  end
end
