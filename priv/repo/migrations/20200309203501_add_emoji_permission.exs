defmodule Ret.Repo.Migrations.AddEmojiPermission do
  use Ecto.Migration

  def change do
    alter table("hubs") do
      modify(:member_permissions, :integer,
        default:
          %{
            spawn_and_move_media: true,
            spawn_camera: true,
            spawn_drawing: true,
            pin_objects: true,
            spawn_emoji: true
          }
          |> Ret.Hub.member_permissions_to_int()
      )
    end
  end
end
