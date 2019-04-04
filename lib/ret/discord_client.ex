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
      redirect_uri: get_redirect_uri()
    }

    "#{@discord_api_base}/oauth2/authorize?" <> URI.encode_query(authorize_params)
  end

  def fetch_access_token(oauth_code) do
    body = {
      :form,
      [
        client_id: module_config(:client_id),
        client_secret: module_config(:client_secret),
        grant_type: "authorization_code",
        code: oauth_code,
        redirect_uri: get_redirect_uri(),
        scope: @oauth_scope
      ]
    }

    "#{@discord_api_base}/oauth2/token"
    |> Ret.HttpUtils.retry_post_until_success(body, [{"content-type", "application/x-www-form-urlencoded"}])
    |> Map.get(:body)
    |> Poison.decode!()
    |> Map.get("access_token")
  end

  def fetch_user_info(access_token) do
    "#{@discord_api_base}/users/@me"
    |> Ret.HttpUtils.retry_get_until_success([{"authorization", "Bearer #{access_token}"}])
    |> Map.get(:body)
    |> Poison.decode!()
  end

  def has_permission?(nil, _, _), do: false

  def has_permission?(%Ret.OAuthProvider{} = oauth_provider, %Ret.HubBinding{} = hub_binding, permission) do
    oauth_provider.provider_account_id |> has_permission?(hub_binding, permission)
  end

  def has_permission?(provider_account_id, %Ret.HubBinding{} = hub_binding, permission)
      when is_binary(provider_account_id) do
    permissions =
      compute_permissions(provider_account_id, hub_binding.community_id, hub_binding.channel_id) |> permissions_to_map

    permissions[permission]
  end

  def api_request(path) do
    "#{@discord_api_base}#{path}"
    |> Ret.HttpUtils.retry_get_until_success([{"authorization", "Bot #{module_config(:bot_token)}"}])
    |> Map.get(:body)
    |> Poison.decode!()
  end

  @none 0x0000_0000
  @all 0xFFFF_FFFF
  @administrator 0x0000_0008
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

  # Convert a permissions bit field integer into a {:permission_name => boolean} map
  defp permissions_to_map(permissions) do
    0..31
    |> Enum.map(&bsl(1, &1))
    |> Enum.map(&{@permissions[&1], (permissions &&& &1) == &1})
    |> Map.new()
  end

  # compute_base_permissions and compute_overwrites based on pseudo-code at 
  # https://discordapp.com/developers/docs/topics/permissions#permission-overwrites
  defp compute_base_permissions(discord_user_id, community_id, user_roles) do
    owner_id =
      case Cachex.fetch(:discord_api, "/guilds/#{community_id}") do
        {status, result} when status in [:commit, :ok] -> result |> Map.get("owner_id")
      end

    if owner_id == discord_user_id do
      @all
    else
      guild_roles =
        case Cachex.fetch(:discord_api, "/guilds/#{community_id}/roles") do
          {status, result} when status in [:commit, :ok] -> result |> Map.new(&{&1["id"], &1})
        end

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

  defp compute_overwrites(base_permissions, discord_user_id, community_id, channel_id, user_roles) do
    if (base_permissions &&& @administrator) == @administrator do
      @all
    else
      permissions = base_permissions

      channel_overwrites =
        case Cachex.fetch(:discord_api, "/channels/#{channel_id}") do
          {status, result} when status in [:commit, :ok] ->
            result
            |> Map.get("permission_overwrites")
            |> Map.new(&{&1["id"], &1})
        end

      overwrite_everyone = channel_overwrites[community_id]

      permissions =
        if overwrite_everyone do
          (permissions &&& ~~~overwrite_everyone["deny"]) ||| overwrite_everyone["allow"]
        else
          permissions
        end

      # Apply role specific overwrites.
      user_permissions = user_roles |> Enum.map(&channel_overwrites[&1]) |> Enum.filter(&(&1 != nil))

      allow = user_permissions |> Enum.reduce(@none, &(&1["allow"] ||| &2))
      deny = user_permissions |> Enum.reduce(@none, &(&1["deny"] ||| &2))

      permissions = (permissions &&& ~~~deny) ||| allow

      # Apply member specific overwrite if it exists.
      overwrite_member = channel_overwrites[discord_user_id]

      permissions =
        if overwrite_member do
          (permissions &&& ~~~overwrite_member.deny) ||| overwrite_member.allow
        else
          permissions
        end

      permissions
    end
  end

  defp compute_permissions(discord_user_id, community_id, channel_id) do
    user_roles =
      case Cachex.fetch(:discord_api, "/guilds/#{community_id}/members/#{discord_user_id}") do
        {:error, _} -> nil
        {status, result} when status in [:commit, :ok] -> result |> Map.get("roles")
      end

    if user_roles == nil do
      @none
    else
      compute_base_permissions(discord_user_id, community_id, user_roles)
      |> compute_overwrites(discord_user_id, community_id, channel_id, user_roles)
    end
  end

  defp get_redirect_uri(), do: RetWeb.Endpoint.url() <> "/api/v1/oauth/discord"

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end
end
