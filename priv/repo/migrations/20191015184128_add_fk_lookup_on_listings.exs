defmodule Ret.Repo.Migrations.AddFkLookupOnListings do
  use Ecto.Migration

  def up do
    execute """
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

    execute 'create or replace view ret0_admin.' || name
    || ' as (select ' || pk || ' as id, '
    || ' cast(' || pk || ' as varchar) as _text_id, '
    || array_to_string(ARRAY(SELECT 'o' || '.' || c.column_name
            FROM information_schema.columns As c
                WHERE table_name = name AND table_schema = 'ret0'
                AND  c.column_name NOT IN(pk) ORDER BY ordinal_position
        ), ',') || extra_columns ||
    				' from ret0.' || name || ' as o ' || extra_clauses || ')';

    end

    $$ language plpgsql;
    """

    execute "drop view ret0_admin.avatar_listings cascade"
    execute "drop view ret0_admin.scene_listings cascade"

    execute "select ret0_admin.create_or_replace_admin_view('avatar_listings', ',cast(avatar_id as varchar) as _avatar_id')"

    execute "grant select, insert, update on ret0_admin.avatar_listings to ret_admin"

    execute """
    create or replace view ret0_admin.pending_avatars as (
         select avatars.id, avatar_sid, avatars.slug, avatars.name, avatars.description, avatars.thumbnail_owned_file_id,
         avatars.base_map_owned_file_id, avatars.emissive_map_owned_file_id, avatars.normal_map_owned_file_id, avatars.orm_map_owned_file_id,
         avatars.attributions, avatar_listings.id as avatar_listing_id, avatars.updated_at, avatars.allow_remixing as allow_remixing, avatars.allow_promotion as allow_promotion,
         avatars.gltf_owned_file_id, avatars.bin_owned_file_id,
         avatars.parent_avatar_listing_id
         from ret0_admin.avatars
         left outer join ret0_admin.avatar_listings on avatar_listings.avatar_id = avatars.id
         where ((avatars.reviewed_at is null or avatars.reviewed_at < avatars.updated_at) and avatars.allow_promotion and avatars.state = 'active')
    );
    """

    execute "grant select on ret0_admin.pending_avatars to ret_admin"

    execute """
    create or replace view ret0_admin.featured_avatar_listings as (
       select id, avatar_listing_sid, slug, name, description, thumbnail_owned_file_id,
       base_map_owned_file_id, emissive_map_owned_file_id, normal_map_owned_file_id, orm_map_owned_file_id,
       attributions, avatar_listings.order, updated_at, tags,
       gltf_owned_file_id, bin_owned_file_id,
       parent_avatar_listing_id
       from ret0_admin.avatar_listings
       where
       state = 'active' and
       tags->'tags' ? 'featured' and
       exists (select id from ret0_admin.avatars s where s.id = avatar_listings.avatar_id and s.state = 'active' and s.allow_promotion)
    );
    """

    execute "grant select, update on ret0_admin.featured_avatar_listings to ret_admin"

    execute "select ret0_admin.create_or_replace_admin_view('scene_listings', ',cast(scene_id as varchar) as _scene_id')"

    execute "grant select, insert, update on ret0_admin.scene_listings to ret_admin"

    execute """
    create or replace view ret0_admin.pending_scenes as (
    		select scenes.id, scene_sid, scenes.slug, scenes.name, scenes.description, scenes.screenshot_owned_file_id, scenes.model_owned_file_id, scenes.scene_owned_file_id, 
    		scenes.attributions, scene_listings.id as scene_listing_id, scenes.updated_at, scenes.allow_remixing as _allow_remixing, scenes.allow_promotion as _allow_promotion
    		from ret0_admin.scenes
    		left outer join ret0_admin.scene_listings on scene_listings.scene_id = scenes.id
    		where ((scenes.reviewed_at is null or scenes.reviewed_at < scenes.updated_at) and scenes.allow_promotion and scenes.state = 'active')
    );
    """

    execute "grant select on ret0_admin.pending_scenes to ret_admin"

    execute """
    create or replace view ret0_admin.featured_scene_listings as (
    select id, scene_listing_sid, slug, name, description, screenshot_owned_file_id, model_owned_file_id, scene_owned_file_id, attributions, scene_listings.order, tags
    from ret0_admin.scene_listings
    where 
    state = 'active' and
    tags->'tags' ? 'featured' and
    exists (select id from ret0_admin.scenes s where s.id = scene_listings.scene_id and s.state = 'active' and s.allow_promotion)
    );
    """

    execute "grant select, update on ret0_admin.featured_scene_listings to ret_admin"
  end

  def down do
  end
end
