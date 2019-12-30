defmodule Ret.Repo.Migrations.CreateSessionStatsTable do
  use Ret.Migration

  @max_year 2030

  def up do
    create table(
             :session_stats,
             prefix: "ret0",
             primary_key: false,
             options: "partition by range (started_at)"
           ) do
      add(:session_id, :uuid, null: false)
      add(:started_at, :utc_datetime, null: false)
      add(:ended_at, :utc_datetime)
      add(:entered_event_payload, :jsonb)
      add(:entered_event_received_at, :utc_datetime)
    end

    for year <- 2018..@max_year,
        month <- 0..11 do
      with end_month <- rem(month + 1, 12),
           end_year <- if(month == 11, do: year + 1, else: year) do
        execute("create table ret0.session_stats_y#{year}_m#{month + 1} partition of session_stats
                 for values from ('#{year}-#{month + 1}-01') to ('#{end_year}-#{end_month + 1}-01')")
      end
    end
  end

  def down do
    for year <- 2018..@max_year,
        month <- 0..11 do
      execute("drop table ret0.session_stats_y#{year}_m#{month + 1}")
    end

    drop(table(:session_stats, prefix: "ret0"))
  end
end
