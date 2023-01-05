defmodule Ret.Repo.Migrations.CreateNodeStatsPartitionsThrough2030 do
  use Ecto.Migration

  import Ret.Repo.MigrationHelpers, only: [next_month: 2]

  @max_year 2030

  def up do
    for y <- 2023..@max_year,
        m <- 1..12 do
      next_month = next_month(y, m)

      execute """
      CREATE TABLE IF NOT EXISTS ret0.node_stats_y#{y}_m#{m} PARTITION OF ret0.node_stats
        FOR VALUES FROM ('#{y}-#{m}-01') TO ('#{next_month.y}-#{next_month.m}-01')
      """
    end
  end

  def down do
    for y <- 2023..@max_year,
        m <- 1..12 do
      execute """
      DROP TABLE ret0.node_stats_y#{y}_m#{m}
      """
    end
  end
end
