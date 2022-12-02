defmodule Ret.Repo.Migrations.NodeStatsTable do
  use Ecto.Migration

  @max_year 2022

  def up do
    create table(
             :node_stats,
             primary_key: false,
             options: "partition by range (measured_at)"
           ) do
      add :node_id, :string, null: false
      add :measured_at, :utc_datetime, null: false
      add :present_sessions, :integer
      add :present_rooms, :integer
    end

    for year <- 2018..@max_year,
        month <- 0..11 do
      with end_month <- rem(month + 1, 12),
           end_year <- if(month == 11, do: year + 1, else: year) do
        execute "create table ret0.node_stats_y#{year}_m#{month + 1} partition of ret0.node_stats
                 for values from ('#{year}-#{month + 1}-01') to ('#{end_year}-#{end_month + 1}-01')"
      end
    end
  end

  def down do
    for year <- 2018..@max_year,
        month <- 0..11 do
      execute "drop table ret0.node_stats_y#{year}_m#{month + 1}"
    end

    drop table(:node_stats)
  end
end
