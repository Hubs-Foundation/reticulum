defmodule Ret.Repo.Migrations.CreateShardingIds do
  use Ecto.Migration

  def up do
    execute "create schema if not exists ret0"
    execute "create sequence ret0.table_id_seq"

    execute """
    CREATE OR REPLACE FUNCTION ret0.next_id(OUT result bigint) AS $$
    DECLARE
    our_epoch bigint := 1505706041000;
    seq_id bigint;
    now_millis bigint;
    shard_id int := 0;
    BEGIN
    SELECT nextval('ret0.table_id_seq') % 1024 INTO seq_id;

    SELECT FLOOR(EXTRACT(EPOCH FROM clock_timestamp()) * 1000) INTO now_millis;
    result := (now_millis - our_epoch) << 23;
    result := result | (shard_id << 10);
    result := result | (seq_id);
    END;
    $$ LANGUAGE PLPGSQL;
    """
  end

  def down do
    execute "DROP SCHEMA ret0 CASCADE"
  end
end
