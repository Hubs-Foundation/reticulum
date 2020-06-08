defmodule Ret.SlackClient do
  use Bitwise
  alias Ret.{BitFieldUtils}

  @oauth_scope "identity.basic,identity.email"
  @slack_api_base "https://slack.com/"

  def get_oauth_url(hub_sid) do
    IO.puts("inside slack get_oauth_url")
    authorize_params = %{
    response_type: "code",
    client_id: module_config(:client_id),
    user_scope: @oauth_scope,
    state: Ret.OAuthToken.token_for_hub(hub_sid),
    redirect_uri: get_redirect_uri()
    }

    "#{@slack_api_base}/oauth/v2/authorize?" <> URI.encode_query(authorize_params)
  end

  #
  def fetch_access_token(oauth_code) do
    IO.puts("inside slack fetch_access_token")
    body = {
    :form,
    [
      client_id: module_config(:client_id),
      client_secret: module_config(:client_secret),
      # grant_type: "authorization_code",
      code: oauth_code,
      redirect_uri: get_redirect_uri(),
      # scope: @oauth_scope
    ]
    }
    %{"authed_user" => authed_user} = "#{@slack_api_base}/api/oauth.v2.access"
    |> Ret.HttpUtils.retry_post_until_success(body, [{"content-type", "application/x-www-form-urlencoded"}])
    |> Map.get(:body)
    |> Poison.decode!()

    Map.get(authed_user, "access_token")
  end

  def fetch_user_info(access_token) do
    IO.puts("SLACK CLIENT fetch_user_info")

    %{"user" => user} = "#{@slack_api_base}/api/users.identity?" <> URI.encode_query(%{token: access_token})
    |> Ret.HttpUtils.retry_get_until_success()
    |> Map.get(:body)
    |> Poison.decode!()

    user |> Map.put("verified", true)
  end

  # users.info
  #
  # users.identity
  # {
  #   user: {
    # id:
  #     email:
  #     name // display name
  #   }
  #   team: {
  #     id
  #     can get "name" if I add identity.team to scopes
  #   }
  # }

  # **** permissions... what are we looking at here

# https://slack.com/api/conversations.members
# { token: <auth token bearing scopes>, channel: <userId>}
# likely see if in response
# {
#   "ok": true,
#   "members": [
#       "U023BECGF",
#       "U061F7AUR",
#       "W012A3CDE"
#   ],
#   "response_metadata": {
#       "next_cursor": "e3VzZXJfaWQ6IFcxMjM0NTY3fQ=="
#   }
# }


@permissions %{
  manage_channels: false,
  kick_members: false,
  view_channel: false
}

  def has_permission?(nil, _, _), do: true

  def has_permission?(%Ret.OAuthProvider{} = oauth_provider, %Ret.HubBinding{} = hub_binding, permission) do
    IO.puts("1_1 inside slack has_permission 1")
    IO.puts(permission)

    returned = oauth_provider.provider_account_id |> has_permission?(hub_binding, permission)

    IO.puts("returned in has_permission 1")
    IO.inspect(returned) # ***

    returned
  end

  def has_permission?(provider_account_id, %Ret.HubBinding{} = hub_binding, permission) do
    IO.puts("1_2 inside slack has_permission 2")
    IO.puts(permission)
    permissions = get_permissions(hub_binding.channel_id, provider_account_id)

    IO.puts(permissions[permission])

    permissions[permission]
  end

  defp get_permissions(channel_id, provider_account_id) do
    IO.puts("SLACK CLIENT get_permissions")
    %{"user" => user} = "#{@slack_api_base}/api/users.info?" <> URI.encode_query(%{token: module_config(:bot_token), user: provider_account_id})
    |> Ret.HttpUtils.retry_get_until_success()
    |> Map.get(:body)
    |> Poison.decode!()

    # check if teamid matches the teamid, if not, all permissions are false return @permissions struct -- necessary?

    # Team permissions
    %{"is_owner" => is_owner, "is_admin" => is_admin} = user

    # Specific channel permissions
    is_member = is_member_in_channel(channel_id, provider_account_id)

    perms = %{@permissions |
      manage_channels: is_admin || is_owner, # change scene
      kick_members: is_admin, # moderate room
      view_channel: is_member # can access room
    }
    IO.inspect(perms)
    perms
  end

  defp is_member_in_channel(channel_id, provider_account_id) do
    IO.puts("SLACK CLIENT is_member_in_channel")
    %{"members" => members} = "#{@slack_api_base}/api/conversations.members?" <> URI.encode_query(%{token: module_config(:bot_token), channel: channel_id})
    |> Ret.HttpUtils.retry_get_until_success()
    |> Map.get(:body)
    |> Poison.decode!()

    Enum.member?(members, provider_account_id)
  end


   # https://slack.com/api/users.info
  #{ token: <auth token bearing scopes>, user: <userId>}
#   res {
#     "ok": true,
#     "user": {
#         "id": "W012A3CDE",
#         "team_id": "T012AB3C4",
#         "name": "spengler",
#         "deleted": false,
#         "color": "9f69e7",
#         "real_name": "Egon Spengler",
#         "tz": "America/Los_Angeles",
#         "tz_label": "Pacific Daylight Time",
#         "tz_offset": -25200,
#         "profile": {
#             "avatar_hash": "ge3b51ca72de",
#             "status_text": "Print is dead",
#             "status_emoji": ":books:",
#             "real_name": "Egon Spengler",
#             "display_name": "spengler",
#             "real_name_normalized": "Egon Spengler",
#             "display_name_normalized": "spengler",
#             "email": "spengler@ghostbusters.example.com",
#             "team": "T012AB3C4"
#         },
#         "is_admin": true,
#         "is_owner": false,
#         "is_primary_owner": false,
#         "is_restricted": false,
#         "is_ultra_restricted": false,
#         "is_bot": false,
#         "updated": 1502138686,
#         "is_app_user": false,
#         "has_2fa": false
#     }
# }



  def fetch_display_name(
      %Ret.OAuthProvider{source: :slack, provider_account_id: provider_account_id},
      %Ret.HubBinding{community_id: _community_id}
      ) do
      IO.puts("SLACK CLIENT: fetch_display_name")


      %{"user" => %{"name" => name}} = "#{@slack_api_base}/api/users.info?" <> URI.encode_query(%{token: module_config(:bot_token), user: provider_account_id}) #access_token
      |> Ret.HttpUtils.retry_get_until_success()
      |> Map.get(:body)
      |> Poison.decode!()

      name
  end

  # not necessary for slack, only discord
  # TODO remove references for slack fetching_community_identifier
  def fetch_community_identifier(%Ret.OAuthProvider{source: _type, provider_account_id: _provider_account_id}) do
    "1234"
  end

  def api_request(path) do
    "#{@slack_api_base}#{path}"
    |> Ret.HttpUtils.retry_get_until_success([{"authorization", "Bot #{module_config(:bot_token)}"}])
    |> Map.get(:body)
    |> Poison.decode!()
  end

  # @none 0x0000_0000
  # @all 0xFFFF_FFFF
  # @administrator 1 <<< 3
  # @permissions %{
  #   (1 <<< 0) => :create_instant_invite,
  #   (1 <<< 1) => :kick_members,
  #   (1 <<< 2) => :ban_members,
  #   (1 <<< 3) => :administrator,
  #   (1 <<< 4) => :manage_channels,
  #   (1 <<< 5) => :manage_guild,
  #   (1 <<< 6) => :add_reactions,
  #   (1 <<< 7) => :view_audit_log,
  #   (1 <<< 8) => :priority_speaker,
  #   (1 <<< 9) => :unused,
  #   (1 <<< 10) => :view_channel,
  #   (1 <<< 11) => :send_messages,
  #   (1 <<< 12) => :send_tts_messages,
  #   (1 <<< 13) => :manage_messages,
  #   (1 <<< 14) => :emded_links,
  #   (1 <<< 15) => :attach_files,
  #   (1 <<< 16) => :read_message_history,
  #   (1 <<< 17) => :mention_everyone,
  #   (1 <<< 18) => :use_external_emojis,
  #   (1 <<< 19) => :unused,
  #   (1 <<< 20) => :connect,
  #   (1 <<< 21) => :speak,
  #   (1 <<< 22) => :mute_members,
  #   (1 <<< 23) => :deafen_members,
  #   (1 <<< 24) => :move_members,
  #   (1 <<< 25) => :use_vad,
  #   (1 <<< 26) => :change_nickname,
  #   (1 <<< 27) => :manage_nicknames,
  #   (1 <<< 28) => :manage_roles,
  #   (1 <<< 29) => :manage_webhooks,
  #   (1 <<< 30) => :manage_emojis,
  #   (1 <<< 31) => :unused
  # }

  # defp permissions_to_map(bit_field) do
  #   bit_field |> BitFieldUtils.permissions_to_map(@permissions)
  # end

  # # compute_base_permissions and compute_overwrites based on pseudo-code at
  # # https://discordapp.com/developers/docs/topics/permissions#permission-overwrites
  # defp compute_base_permissions(discord_user_id, community_id, user_roles) do
  #   owner_id =
  #   case Cachex.fetch(:slack_api, "/guilds/#{community_id}") do
  #     {status, result} when status in [:commit, :ok] -> result |> Map.get("owner_id")
  #   end

  #   if owner_id == discord_user_id do
  #   @all
  #   else
  #   guild_roles =
  #     case Cachex.fetch(:slack_api, "/guilds/#{community_id}/roles") do
  #     {status, result} when status in [:commit, :ok] -> result |> Map.new(&{&1["id"], &1})
  #     end

  #   role_everyone = guild_roles[community_id]
  #   permissions = role_everyone["permissions"]

  #   user_permissions = user_roles |> Enum.map(&guild_roles[&1]["permissions"])

  #   permissions = user_permissions |> Enum.reduce(permissions, &(&1 ||| &2))

  #   if (permissions &&& @administrator) == @administrator do
  #     @all
  #   else
  #     permissions
  #   end
  #   end
  # end

  # defp compute_overwrites(base_permissions, discord_user_id, community_id, channel_id, user_roles) do
  #   IO.puts("SLACK CLIENT: compute overwrites")
  #   if (base_permissions &&& @administrator) == @administrator do
  #   @all
  #   else
  #   permissions = base_permissions

  #   channel_overwrites =
  #     case Cachex.fetch(:slack_api, "/channels/#{channel_id}") do
  #     {status, result} when status in [:commit, :ok] ->
  #       result
  #       |> Map.get("permission_overwrites")
  #       |> Map.new(&{&1["id"], &1})
  #     end

  #   overwrite_everyone = channel_overwrites[community_id]

  #   permissions =
  #     if overwrite_everyone do
  #     (permissions &&& ~~~overwrite_everyone["deny"]) ||| overwrite_everyone["allow"]
  #     else
  #     permissions
  #     end

  #   # Apply role specific overwrites.
  #   user_permissions = user_roles |> Enum.map(&channel_overwrites[&1]) |> Enum.filter(&(&1 != nil))

  #   allow = user_permissions |> Enum.reduce(@none, &(&1["allow"] ||| &2))
  #   deny = user_permissions |> Enum.reduce(@none, &(&1["deny"] ||| &2))

  #   permissions = (permissions &&& ~~~deny) ||| allow

  #   # Apply member specific overwrite if it exists.
  #   overwrite_member = channel_overwrites[discord_user_id]

  #   permissions =
  #     if overwrite_member do
  #     (permissions &&& ~~~overwrite_member["deny"]) ||| overwrite_member["allow"]
  #     else
  #     permissions
  #     end

  #   permissions
  #   end
  # end

  # defp compute_permissions(discord_user_id, community_id, channel_id) do
  #   IO.puts("SLACK CLIENT: compute permissions")
  #   user_roles =
  #   case Cachex.fetch(:slack_api, "/guilds/#{community_id}/members/#{discord_user_id}") do
  #     {:error, _} -> nil
  #     {status, result} when status in [:commit, :ok] -> result |> Map.get("roles")
  #   end

  #   if user_roles == nil do
  #   @none
  #   else
  #   compute_base_permissions(discord_user_id, community_id, user_roles)
  #   |> compute_overwrites(discord_user_id, community_id, channel_id, user_roles)
  #   end
  # end

  defp get_redirect_uri(), do: RetWeb.Endpoint.url() <> "/api/v1/oauth/slack"

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end
  end
