defmodule Ret.Repo.Migrations.AddPermissionsToHubs do
  use Bitwise
  use Ecto.Migration

  def change do
    alter table("hubs") do
      add(:member_permissions, :integer,
        default:
          %{
            spawn_and_move_media: true,
            spawn_camera: true,
            spawn_drawing: true,
            pin_objects: true
          }
          |> Ret.Hub.member_permissions_to_int()
      )
    end
  end
end
