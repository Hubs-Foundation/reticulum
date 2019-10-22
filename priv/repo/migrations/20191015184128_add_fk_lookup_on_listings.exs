defmodule Ret.Repo.Migrations.AddFkLookupOnListings do
  use Ecto.Migration

  def up do
    # Move extra-columns to the end since otherwise we can't add new ones
    execute("""
      create or replace function ret0_admin.create_or_replace_admin_view(
      name text,
      extra_columns text default '',
      extra_clauses text default ''
    )
    returns void as
    $$
    declare
    pk character varying(255);
    begin

    -- Get the primary key
    SELECT
      pg_attribute.attname into pk
    FROM pg_index, pg_class, pg_attribute, pg_namespace
    WHERE
      pg_class.oid = ('ret0.' || name)::regclass AND
      indrelid = pg_class.oid AND
      nspname = 'ret0' AND
      pg_class.relnamespace = pg_namespace.oid AND
      pg_attribute.attrelid = pg_class.oid AND
      pg_attribute.attnum = any(pg_index.indkey)
     AND indisprimary;

    -- Create a view with the primary key renamed to id 
    execute 'create or replace view ret0_admin.' || name
    || ' as (select ' || pk || ' as id, '
    || ' cast(' || pk || ' as varchar) as _text_id, '
    || array_to_string(ARRAY(SELECT 'o' || '.' || c.column_name
            FROM information_schema.columns As c
                WHERE table_name = name AND table_schema = 'ret0'
                AND  c.column_name NOT IN(pk)
        ), ',') || extra_columns ||
    				' from ret0.' || name || ' as o ' || extra_clauses || ')';

    end

    $$ language plpgsql;
    """)

    execute(
      "select ret0_admin.create_or_replace_admin_view('avatar_listings', ',cast(avatar_id as varchar) as _avatar_id')"
    )

    execute("grant select, insert, update on ret0_admin.avatar_listings to ret_admin;")

    execute(
      "select ret0_admin.create_or_replace_admin_view('scene_listings', ',cast(scene_id as varchar) as _scene_id')"
    )

    execute("grant select, insert, update on ret0_admin.scene_listings to ret_admin;")
  end

  def down do
  end
end
