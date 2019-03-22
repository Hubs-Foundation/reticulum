defmodule Ret.DiscordClient do
  use Bitwise

  @oauth_scope "identify email"
  @discord_api_base "https://discordapp.com/api/v6"

  def get_oauth_url(hub_sid) do
    authorize_params = %{
      response_type: "code",
      client_id: module_config(:client_id),
      scope: @oauth_scope,
      state: Ret.OAuthToken.token_for_hub(hub_sid),
      redirect_uri: get_redirect_uri
    }

    "#{@discord_api_base}/oauth2/authorize?" <> URI.encode_query(authorize_params)
  end

  def get_access_token(oauth_code) do
    body = {
      :form,
      [
        client_id: module_config(:client_id),
        client_secret: module_config(:client_secret),
        grant_type: "authorization_code",
        code: oauth_code,
        redirect_uri: get_redirect_uri,
        scope: @oauth_scope
      ]
    }

    HTTPoison.post!("#{@discord_api_base}/oauth2/token", body, %{
      "content-type" => "application/x-www-form-urlencoded"
    })
    |> Map.get(:body)
    |> Poison.decode!()
    |> Map.get("access_token")
  end

  def get_user_info(access_token) do
    HTTPoison.get!("#{@discord_api_base}/users/@me", %{"authorization" => "Bearer #{access_token}"})
    |> Map.get(:body)
    |> Poison.decode!()
  end

  def api_request(path) do
    HTTPoison.get!("#{@discord_api_base}#{path}", %{"authorization" => "Bot #{module_config(:bot_token)}"})
    |> Map.get(:body)
    |> Poison.decode!()
  end

  @administrator 0x0000_0008
  @all 0xFFFF_FFFF
  @permissions %{
    0x0000_0001 => :create_instant_invite,
    0x0000_0002 => :kick_members,
    0x0000_0004 => :ban_members,
    0x0000_0008 => :administrator,
    0x0000_0010 => :manage_channels,
    0x0000_0020 => :manage_guild,
    0x0000_0040 => :add_reactions,
    0x0000_0080 => :view_audit_log,
    0x0000_0100 => :priority_speaker,
    0x0000_0200 => :unused,
    0x0000_0400 => :view_channel,
    0x0000_0800 => :send_messages,
    0x0000_1000 => :send_tts_messages,
    0x0000_2000 => :manage_messages,
    0x0000_4000 => :emded_links,
    0x0000_8000 => :attach_files,
    0x0001_0000 => :read_message_history,
    0x0002_0000 => :mention_everyone,
    0x0004_0000 => :use_external_emojis,
    0x0008_0000 => :unused,
    0x0010_0000 => :connect,
    0x0020_0000 => :speak,
    0x0040_0000 => :mute_members,
    0x0080_0000 => :deafen_members,
    0x0100_0000 => :move_members,
    0x0200_0000 => :use_vad,
    0x0400_0000 => :change_nickname,
    0x0800_0000 => :manage_nicknames,
    0x1000_0000 => :manage_roles,
    0x2000_0000 => :manage_webhooks,
    0x4000_0000 => :manage_emojis,
    0x8000_0000 => :unused
  }

  def permissions_to_map(permissions) do
    0..31
    |> Enum.map(&bsl(1, &1))
    |> Enum.map(&{@permissions[&1], (permissions &&& &1) == &1})
    |> Map.new()
  end

  # compute_base_permissions and compute_overwrites based on pseudo-code at 
  # https://discordapp.com/developers/docs/topics/permissions#permission-overwrites
  def compute_base_permissions(account_id, community_id, user_roles) do
    owner_id = api_request("/guilds/#{community_id}") |> Map.get("owner_id")

    if owner_id == account_id do
      @all
    else
      guild_roles = api_request("/guilds/#{community_id}/roles") |> Map.new(&{&1["id"], &1})
      role_everyone = guild_roles[community_id]
      permissions = role_everyone["permissions"]

      user_permissions = user_roles |> Enum.map(&guild_roles[&1]["permissions"])

      permissions = user_permissions |> Enum.reduce(permissions, &(&1 ||| &2))

      if (permissions &&& @administrator) == @administrator do
        @all
      else
        permissions
      end
    end
  end

  def compute_overwrites(base_permissions, account_id, community_id, channel_id, user_roles) do
    if (base_permissions &&& @administrator) == @administrator do
      @all
    else
      permissions = base_permissions

      channel_overwrites =
        api_request("/channels/#{channel_id}") |> Map.get("permission_overwrites") |> Map.new(&{&1["id"], &1})

      overwrite_everyone = channel_overwrites[community_id]

      if overwrite_everyone do
        permissions = permissions &&& ~~~overwrite_everyone["deny"]
        permissions = permissions ||| overwrite_everyone["allow"]
      end

      # Apply role specific overwrites.
      user_permissions = user_roles |> Enum.map(&channel_overwrites[&1]) |> Enum.filter(&(&1 != nil))

      allow = user_permissions |> Enum.reduce(0, &(&1["allow"] ||| &2))
      deny = user_permissions |> Enum.reduce(0, &(&1["deny"] ||| &2))

      permissions = permissions &&& ~~~deny
      permissions = permissions ||| allow

      # Apply member specific overwrite if it exists.
      overwrite_member = channel_overwrites[account_id]

      if overwrite_member do
        permissions = permissions &&& ~~~overwrite_member.deny
        permissions = permissions ||| overwrite_member.allow
      end

      permissions
    end
  end

  def compute_permissions(account_id, community_id, channel_id) do
    user_roles = api_request("/guilds/#{community_id}/members/#{account_id}") |> Map.get("roles")

    compute_base_permissions(account_id, community_id, user_roles)
    |> compute_overwrites(account_id, community_id, channel_id, user_roles)
  end

  def member_of_channel?(account_id, community_id, channel_id) do
    permissions = compute_permissions(account_id, community_id, channel_id) |> permissions_to_map
    permissions[:view_channel]
  end

  defp get_redirect_uri(), do: RetWeb.Endpoint.url() <> "/api/v1/oauth/discord"

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end
end
