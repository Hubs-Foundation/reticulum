defmodule Ret.Repo.Migrations.AddFkLookupOnListings do
  use Ecto.Migration

  def up do
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
