defmodule Ret.SessionStat do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Ret.SessionStat
  @schema_prefix "ret0"
  @primary_key false

  schema "session_stats" do
    field(:session_id, :binary_id)
    field(:started_at, :utc_datetime)
    field(:ended_at, :utc_datetime)
    field(:entered_event_payload, :map)
    field(:entered_event_received_at, :utc_datetime)
  end

  def changeset(%SessionStat{} = session_stat, attrs) do
    session_stat
    |> cast(attrs, [
      :session_id,
      :started_at,
      :ended_at,
      :entered_event_payload,
      :entered_event_received_at
    ])
  end

  def stat_query_for_socket(socket) do
    # Use date constraint to limit partitions to recent partitions, assume sessions don't last more than a week
    from(
      s in SessionStat,
      where:
        s.session_id == ^socket.assigns.session_id and
          s.started_at >= datetime_add(^NaiveDateTime.utc_now(), -1, "week")
    )
  end

  #
  def get_aggregated_stats_for_day(_utc_timestamp) do

    fragment("?::date = ?::date", test.timestamp, type(^now, :naive_datetime)


    query = from(s in SessionStat, where: fragment("?::date <= ?::date", s.started_at, type(^now, :naive_datetime) and fragment("?::date >= ?::date", s.ended_at, type(^now, :naive_datetime))
    Ret.Repo.aggregate( queryable, aggregate, field, opts )

# Returns the average number of visits for the top 10
query = from Post, limit: 10
Repo.aggregate(query, :avg, :visits)
  end
end
