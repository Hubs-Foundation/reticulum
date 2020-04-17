defmodule Ret.Repo.Migrations.AddCoturnSchema do
  use Ecto.Migration

  def up do
    coturn_password = Application.get_env(:ret, __MODULE__)[:coturn_password]

    execute("create schema if not exists coturn")

    execute(
      "create table coturn.turn_secret (realm varchar(127), value varchar(256), inserted_at timestamp, updated_at timestamp)"
    )

    execute(
      "create table coturn.allowed_peer_ip (realm varchar(127), ip_range varchar(256), inserted_at timestamp, updated_at timestamp)"
    )

    execute(
      "create table coturn.denied_peer_ip (realm varchar(127), ip_range varchar(256), inserted_at timestamp, updated_at timestamp)"
    )

    if coturn_password do
      execute("""
      DO
      $do$
      BEGIN
         IF NOT EXISTS (
            SELECT                       -- SELECT list can stay empty for this
            FROM   pg_catalog.pg_roles
            WHERE  rolname = 'coturn') THEN

            CREATE ROLE coturn LOGIN PASSWORD '#{coturn_password}';
         END IF;
      END
      $do$;
      """)

      execute("""
      do 
      $$ 
      begin
        execute format('grant connect on database %I to coturn', current_database());
      end;
      $$;
      """)

      execute("grant usage on schema coturn to coturn;")
      execute("grant all privileges on all tables in schema coturn to coturn;")
    end
  end

  def down do
    execute("drop schema coturn cascade")
  end
end
