defmodule Ret.Repo.Migrations.AddFlyPermission do
  use Ecto.Migration

  def up do
    alter table("hubs") do
      modify(:member_permissions, :integer,
        default:
          %{
            spawn_and_move_media: true,
            spawn_camera: true,
            spawn_drawing: true,
            pin_objects: true,
            spawn_emoji: true,
            fly: true,
            voice_chat: true,
            text_chat: true
          }
          |> Ret.Hub.member_permissions_to_int()
      )
    end

    execute("UPDATE ret0.hubs SET member_permissions = member_permissions | 192;")
  end

  def down do
    alter table("hubs") do
      modify(:member_permissions, :integer,
        default:
          %{
            spawn_and_move_media: true,
            spawn_camera: true,
            spawn_drawing: true,
            pin_objects: true,
            spawn_emoji: true,
            fly: true
          }
          |> Ret.Hub.member_permissions_to_int()
      )
    end

    execute("UPDATE ret0.hubs SET member_permissions = member_permissions & ~192;")
  end
end
