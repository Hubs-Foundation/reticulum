defmodule Ret.NodeStat do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ret.NodeStat
  @schema_prefix "ret0"
  @primary_key false

  schema "node_stats" do
    field(:node_id, :binary)
    field(:measured_at, :utc_datetime)
    field(:present_sessions, :integer)
    field(:present_rooms, :integer)
  end

  def changeset(%NodeStat{} = node_stat, attrs) do
    node_stat
    |> cast(attrs, [
      :node_id,
      :measured_at,
      :present_sessions,
      :present_rooms
    ])
  end
end
