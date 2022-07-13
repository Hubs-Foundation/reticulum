defmodule Ret.NodeStat do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Ret.{NodeStat, Repo}
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

  def max_ccu_for_time_range(start_time, end_time) do
    max_ccu =
      from(ns in NodeStat,
        select: max(ns.present_sessions),
        where: ns.measured_at >= ^start_time and ns.measured_at < ^end_time
      )
      |> Repo.one()

    if max_ccu === nil, do: 0, else: max_ccu
  end

  # TODO REMOVE
  def seed_node_stats() do
    # Convert to dates
    today_date = NaiveDateTime.utc_now() |> NaiveDateTime.to_date()
    tomorrow_date = today_date |> Date.add(1)
    yesterday_date = today_date |> Date.add(-1)

    # Convert to dates with times
    {:ok, time} = Time.new(0, 0, 0, 0)
    {:ok, today_time} = today_date |> NaiveDateTime.new(time)

    {:ok, yesterday_time} = yesterday_date |> NaiveDateTime.new(time)
    {:ok, tomorrow_time} = tomorrow_date |> NaiveDateTime.new(time)

    Enum.each([0, 10, 5], fn count ->
      {:ok, _} =
        with node_id <- Node.self() |> to_string,
             measured_at <- today_time |> NaiveDateTime.truncate(:second),
             present_sessions <- count,
             present_rooms <- 1 do
          %NodeStat{}
          |> NodeStat.changeset(%{
            node_id: node_id,
            measured_at: measured_at,
            present_sessions: present_sessions,
            present_rooms: present_rooms
          })
          |> Repo.insert()
        end
    end)

    Enum.each([20], fn count ->
      {:ok, _} =
        with node_id <- Node.self() |> to_string,
             measured_at <- tomorrow_time |> NaiveDateTime.truncate(:second),
             present_sessions <- count,
             present_rooms <- 1 do
          %NodeStat{}
          |> NodeStat.changeset(%{
            node_id: node_id,
            measured_at: measured_at,
            present_sessions: present_sessions,
            present_rooms: present_rooms
          })
          |> Repo.insert()
        end
    end)

    Enum.each([20], fn count ->
      {:ok, _} =
        with node_id <- Node.self() |> to_string,
             measured_at <- yesterday_time |> NaiveDateTime.truncate(:second),
             present_sessions <- count,
             present_rooms <- 1 do
          %NodeStat{}
          |> NodeStat.changeset(%{
            node_id: node_id,
            measured_at: measured_at,
            present_sessions: present_sessions,
            present_rooms: present_rooms
          })
          |> Repo.insert()
        end
    end)
  end

  def get_times() do
    # Convert to dates
    today_date = NaiveDateTime.utc_now() |> NaiveDateTime.to_date() |> Date.add(-1)
    tomorrow_date = today_date # |> Date.add(1)

    # Convert to dates with times
    {:ok, time} = Time.new(0, 0, 0, 0)
    {:ok, start_date_time} = today_date |> NaiveDateTime.new(time)
    {:ok, end_date_time} = tomorrow_date |> NaiveDateTime.new(time)

    %{start_date_time: start_date_time, end_date_time: end_date_time}
  end

  # Ret.NodeStat.seed_node_stats()
  # %{start_date_time: start_date_time, end_date_time: end_date_time} = Ret.NodeStat.get_times()
  # Ret.NodeStat.max_ccu_for_time_range(start_date_time, end_date_time)
end
