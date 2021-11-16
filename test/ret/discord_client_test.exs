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

  @discord_api_base "https://discordapp.com/api/v6"

  setup_all do
    Cachex.put(:discord_api, "/guilds/#{@community_id}", %{"owner_id" => @owner_user_id})

    Cachex.put(:discord_api, "/guilds/#{@community_id}/roles", [
      %{"id" => @community_id, "permissions" => @view_channel},
      %{"id" => @moderator_role, "permissions" => @view_channel}
    ])

    Cachex.put(:discord_api, "/guilds/#{@community_id}/members/#{@moderator_user_id}", %{"roles" => [@moderator_role]})
    Cachex.put(:discord_api, "/guilds/#{@community_id}/members/#{@owner_user_id}", %{"roles" => []})
    Cachex.put(:discord_api, "/guilds/#{@community_id}/members/#{@regular_user_id}", %{"roles" => []})

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
    assert @regular_user_id |> DiscordClient.has_permission?(@general_channel_binding, :view_channel)
  end

  test "regular member should not be able to view restricted channel" do
    refute @regular_user_id |> DiscordClient.has_permission?(@restricted_channel_binding, :view_channel)
  end

  test "owner should be able to view restricted channel" do
    assert @owner_user_id |> DiscordClient.has_permission?(@restricted_channel_binding, :view_channel)
  end

  test "moderator should be able to view restricted channel" do
    assert @moderator_user_id |> DiscordClient.has_permission?(@restricted_channel_binding, :view_channel)
  end

  @tag only: true
  test "should make a properly structured http request" do
    parent = self()
    mock_asserts = make_ref()

    Mox.set_mox_global()
    Mox.defmock(Ret.HttpMock, for: HTTPoison.Base)
    Application.put_env(:ret, Ret.HttpUtils, %{:http_client => Ret.HttpMock})

    Ret.HttpMock
    |> Mox.expect(:request, 1, fn verb, url, _body, headers, _options ->
      was_discord_api_request = url |> String.contains?(@discord_api_base)

      header_keys = headers |> Enum.map(fn {k, _v} -> k |> String.downcase() end)
      discord_request_has_ua_header = header_keys |> Enum.member?("user-agent")

      send(
        parent,
        {mock_asserts,
         [
           http_verb: verb,
           was_discord_api_request: was_discord_api_request,
           discord_request_has_ua_header: discord_request_has_ua_header
         ]}
      )
    end)

    DiscordClient.has_permission?("test", %Ret.HubBinding{community_id: "test", channel_id: "test"}, :view_channel)

    assert_receive(
      {^mock_asserts,
       [
         http_verb: :get,
         was_discord_api_request: true,
         discord_request_has_ua_header: false
       ]},
      5000
    )
  end
end
