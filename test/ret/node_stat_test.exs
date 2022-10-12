defmodule Ret.NodeStatTest do
  use Ret.DataCase
  alias Ret.{NodeStat, Repo}

  describe "NodeStat.max_ccu_for_time_range() tests" do
    test "Get max correctly for today" do
      %{today: today} = get_times()

      [{today, [0, 10, 5]}]
      |> seed_node_stats()

      assert 10 == NodeStat.max_ccu_for_time_range(today.start_time, today.end_time)
    end

    test "Return 0 for no NodeStats collected for today" do
      # Do not seed database
      %{today: today} = get_times()
      assert 0 == NodeStat.max_ccu_for_time_range(today.start_time, today.end_time)
    end

    test "Do not return outside of time boundary" do
      %{today: today, tomorrow: tomorrow, yesterday: yesterday} = get_times()

      [{today, [0, 10, 5]}, {tomorrow, [20]}, {yesterday, [20]}]
      |> seed_node_stats()

      assert 10 == NodeStat.max_ccu_for_time_range(today.start_time, today.end_time)
      assert 20 == NodeStat.max_ccu_for_time_range(yesterday.start_time, yesterday.end_time)
      assert 20 == NodeStat.max_ccu_for_time_range(tomorrow.start_time, tomorrow.end_time)
    end
  end

  # tuple_list = [{%{start_time}, [1,2,3]}, {%{start_time}, [1]}, ... ]
  defp seed_node_stats(tuple_list) do
    Enum.each(tuple_list, fn {time, count_list} ->
      %{start_time: start_time} = time

      Enum.each(count_list, fn count ->
        %NodeStat{}
        |> NodeStat.changeset(%{
          measured_at: start_time |> NaiveDateTime.truncate(:second),
          present_sessions: count,
          node_id: Node.self() |> to_string,
          present_rooms: 1
        })
        |> Repo.insert()
      end)
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
