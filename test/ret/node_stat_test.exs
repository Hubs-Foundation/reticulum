defmodule Ret.NodeStatTest do
  use Ret.DataCase
  alias Ret.{NodeStat, Repo}

  describe "NodeStat.max_ccu_for_time_range() tests" do
    @tag marked: true
    test "Get max correctly for today" do
      seed_today_node_stats([0, 10, 5])

      %{today: today} = get_times()

      assert 10 == NodeStat.max_ccu_for_time_range(today.start_time, today.end_time)
    end

    @tag marked: true
    test "Return 0 for no NodeStats collected for today" do
      # Do not seed database
      %{today: today} = get_times()
      assert 0 == NodeStat.max_ccu_for_time_range(today.start_time, today.end_time)
    end

    @tag marked: true
    test "Do not return outside of time boundary" do
      seed_today_node_stats([0, 10, 5])
      seed_tomorrow_and_yesterday_node_stats(20)

      %{today: today, tomorrow: tomorrow, yesterday: yesterday} = get_times()

      assert 10 == NodeStat.max_ccu_for_time_range(today.start_time, today.end_time)
      assert 20 == NodeStat.max_ccu_for_time_range(yesterday.start_time, yesterday.end_time)
      assert 20 == NodeStat.max_ccu_for_time_range(tomorrow.start_time, tomorrow.end_time)
    end
  end

  defp seed_tomorrow_and_yesterday_node_stats(count) do
    %{tomorrow: %{start_time: start_time_tomorrow}, yesterday: %{start_time: start_time_yesterday}} = get_times()
    # Tomorrow
    %NodeStat{}
    |> NodeStat.changeset(%{
      measured_at: start_time_tomorrow |> NaiveDateTime.truncate(:second),
      present_sessions: count,
      node_id: Node.self() |> to_string,
      present_rooms: 1
    })
    |> Repo.insert()

    # Yesterday
    %NodeStat{}
    |> NodeStat.changeset(%{
      measured_at: start_time_yesterday |> NaiveDateTime.truncate(:second),
      present_sessions: count,
      node_id: Node.self() |> to_string,
      present_rooms: 1
    })
    |> Repo.insert()
  end

  defp seed_today_node_stats(count_list) do
    %{today: today} = get_times()

    # Today 10, 5, 0 present_sessions
    Enum.each(count_list, fn count ->
      %NodeStat{}
      |> NodeStat.changeset(%{
        measured_at: today.start_time |> NaiveDateTime.truncate(:second),
        present_sessions: count,
        node_id: Node.self() |> to_string,
        present_rooms: 1
      })
      |> Repo.insert()
    end)
  end

  defp date_to_date_time(date, time) do
    {:ok, date_time} = date |> NaiveDateTime.new(time)
    date_time
  end

  def get_times() do
    # Convert to dates
    today_date = NaiveDateTime.utc_now() |> NaiveDateTime.to_date()
    tomorrow_date = today_date |> Date.add(1)
    two_days_date = today_date |> Date.add(2)
    yesterday_date = today_date |> Date.add(-1)

    {:ok, time} = Time.new(0, 0, 0, 0)

    %{
      today: %{start_time: today_date |> date_to_date_time(time), end_time: tomorrow_date |> date_to_date_time(time)},
      yesterday: %{
        start_time: yesterday_date |> date_to_date_time(time),
        end_time: today_date |> date_to_date_time(time)
      },
      tomorrow: %{
        start_time: tomorrow_date |> date_to_date_time(time),
        end_time: two_days_date |> date_to_date_time(time)
      }
    }
  end
end
