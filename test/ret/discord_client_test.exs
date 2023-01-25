defmodule Ret.DiscordClientTest do
  use Ret.DataCase

  alias Ret.DiscordClient

  @none 0x0000_0000
  @view_channel 0x0000_0400

  @community_id "1234"
  @moderator_role "9999"

  @owner_user_id "1000"
  @moderator_user_id "2000"
  @regular_user_id "3000"

  @general_channel_id "4567"
  @restricted_channel_id "8910"

  @general_channel_binding %Ret.HubBinding{
    community_id: @community_id,
    channel_id: @general_channel_id
  }
  @restricted_channel_binding %Ret.HubBinding{
    community_id: @community_id,
    channel_id: @restricted_channel_id
  }

  setup_all do
    Cachex.put(:discord_api, "/guilds/#{@community_id}", %{"owner_id" => @owner_user_id})

    Cachex.put(:discord_api, "/guilds/#{@community_id}/roles", [
      %{"id" => @community_id, "permissions" => @view_channel},
      %{"id" => @moderator_role, "permissions" => @view_channel}
    ])

    Cachex.put(:discord_api, "/guilds/#{@community_id}/members/#{@moderator_user_id}", %{
      "roles" => [@moderator_role]
    })

    Cachex.put(:discord_api, "/guilds/#{@community_id}/members/#{@owner_user_id}", %{
      "roles" => []
    })

    Cachex.put(:discord_api, "/guilds/#{@community_id}/members/#{@regular_user_id}", %{
      "roles" => []
    })

    Cachex.put(:discord_api, "/channels/#{@general_channel_id}", %{"permission_overwrites" => []})

    Cachex.put(:discord_api, "/channels/#{@restricted_channel_id}", %{
      "permission_overwrites" => [
        %{"id" => @community_id, "allow" => @none, "deny" => @view_channel},
        %{"id" => @moderator_role, "allow" => @view_channel, "deny" => @none},
        %{"id" => @regular_user_id, "allow" => @none, "deny" => @none}
      ]
    })

    :ok
  end

  test "regular member should be able to view general channel" do
    assert @regular_user_id
           |> DiscordClient.has_permission?(@general_channel_binding, :view_channel)
  end

  test "regular member should not be able to view restricted channel" do
    refute @regular_user_id
           |> DiscordClient.has_permission?(@restricted_channel_binding, :view_channel)
  end

  test "owner should be able to view restricted channel" do
    assert @owner_user_id
           |> DiscordClient.has_permission?(@restricted_channel_binding, :view_channel)
  end

  test "moderator should be able to view restricted channel" do
    assert @moderator_user_id
           |> DiscordClient.has_permission?(@restricted_channel_binding, :view_channel)
  end
end
