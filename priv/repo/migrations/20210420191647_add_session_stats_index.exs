defmodule Ret.Repo.Migrations.AddSessionStatsIndex do
  use Ecto.Migration

  @max_year 2022

  def up do
    for year <- 2018..@max_year,
        month <- 0..11 do
      execute """
        create index session_stats_y#{year}_m#{month + 1}_session_id 
          on ret0.session_stats_y#{year}_m#{month + 1} (session_id)
      """
    end
  end

  def down do
    for year <- 2018..@max_year,
        month <- 0..11 do
      execute "drop index session_stats_y#{year}_m#{month + 1}_session_id"
    end
  end
end
