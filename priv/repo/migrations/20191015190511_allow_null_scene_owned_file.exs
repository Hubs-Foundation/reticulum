defmodule Ret.Repo.Migrations.AllowNullSceneOwnedFile do
  use Ecto.Migration

  def up do
    # Drops scene listings view and featured scenes view
    execute("drop view ret0_admin.scene_listings cascade")

    # Hosted spoke won't necessarily fill this file in

    alter table("scene_listings") do
      modify(:scene_owned_file_id, :bigint, null: true)
    end

    # Re-create views
    execute(
      "select ret0_admin.create_or_replace_admin_view('scene_listings', ',cast(scene_id as varchar) as _scene_id')"
    )

    execute("grant select, insert, update on ret0_admin.scene_listings to ret_admin;")

    execute("""
    create or replace view ret0_admin.featured_scene_listings as (
    select id, scene_listing_sid, slug, name, description, screenshot_owned_file_id, model_owned_file_id, scene_owned_file_id, attributions, scene_listings.order, tags
    from ret0_admin.scene_listings
    where 
    state = 'active' and
    tags->'tags' ? 'featured' and
    exists (select id from ret0_admin.scenes s where s.id = scene_listings.scene_id and s.state = 'active' and s.allow_promotion)
    );
    """)

    execute("grant select, update on ret0_admin.featured_scene_listings to ret_admin;")
  end

  def down do
    execute("drop view ret0_admin.scene_listings cascade")

    alter table("scene_listings") do
      modify(:scene_owned_file_id, :bigint, null: false)
    end

    execute(
      "select ret0_admin.create_or_replace_admin_view('scene_listings', ',cast(scene_id as varchar) as _scene_id')"
    )

    execute("grant select, insert, update on ret0_admin.scene_listings to ret_admin;")

    execute("""
    create or replace view ret0_admin.featured_scene_listings as (
    select id, scene_listing_sid, slug, name, description, screenshot_owned_file_id, model_owned_file_id, scene_owned_file_id, attributions, scene_listings.order, tags
    from ret0_admin.scene_listings
    where 
    state = 'active' and
    tags->'tags' ? 'featured' and
    exists (select id from ret0_admin.scenes s where s.id = scene_listings.scene_id and s.state = 'active' and s.allow_promotion)
    );
    """)

    execute("grant select, update on ret0_admin.featured_scene_listings to ret_admin;")
  end
end
