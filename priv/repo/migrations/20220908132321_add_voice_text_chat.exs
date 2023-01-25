defmodule Ret.Repo.Migrations.AddVoiceChatPermission do
  use Ecto.Migration

  def up do
    alter table("hubs") do
      modify :member_permissions, :integer,
        default:
          Ret.Hub.member_permissions_to_int(%{
            spawn_and_move_media: true,
            spawn_camera: true,
            spawn_drawing: true,
            pin_objects: true,
            spawn_emoji: true,
            fly: true,
            voice_chat: true,
            text_chat: true
          })
    end

    execute "UPDATE ret0.hubs SET member_permissions = member_permissions | 192"
  end

  def down do
    alter table("hubs") do
      modify :member_permissions, :integer,
        default:
          Ret.Hub.member_permissions_to_int(%{
            spawn_and_move_media: true,
            spawn_camera: true,
            spawn_drawing: true,
            pin_objects: true,
            spawn_emoji: true,
            fly: true
          })
    end

    execute "UPDATE ret0.hubs SET member_permissions = member_permissions & ~192"
  end
end
