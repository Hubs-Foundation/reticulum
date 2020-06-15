defmodule Ret.SlackClient do
  use Bitwise
  alias Ret.{BitFieldUtils}

  @oauth_scope "identity.basic,identity.email"
  @slack_api_base "https://slack.com/"

  def get_oauth_url(hub_sid) do
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
    %{"user" => user} = "#{@slack_api_base}/api/users.identity?" <> URI.encode_query(%{token: access_token})
    |> Ret.HttpUtils.retry_get_until_success()
    |> Map.get(:body)
    |> Poison.decode!()

    user |> Map.put("verified", true)
  end


@permissions %{
  manage_channels: false,
  kick_members: false,
  view_channel: false
}

  def has_permission?(nil, _, _), do: true

  def has_permission?(%Ret.OAuthProvider{} = oauth_provider, %Ret.HubBinding{} = hub_binding, permission) do
    oauth_provider.provider_account_id |> has_permission?(hub_binding, permission)
  end

  def has_permission?(provider_account_id, %Ret.HubBinding{} = hub_binding, permission) do
    permissions = get_permissions(hub_binding.channel_id, provider_account_id)

    permissions[permission]
  end

  defp get_permissions(channel_id, provider_account_id) do
    %{"user" => user} = "#{@slack_api_base}/api/users.info?" <> URI.encode_query(%{token: module_config(:bot_token), user: provider_account_id})
    |> Ret.HttpUtils.retry_get_until_success()
    |> Map.get(:body)
    |> Poison.decode!()

    # Team permissions
    %{"is_owner" => is_owner, "is_admin" => is_admin} = user

    # Specific channel permissions
    is_member = is_member_in_channel(channel_id, provider_account_id)

    perms = %{@permissions |
      manage_channels: is_member, # change scene
      kick_members: is_member, # moderate room
      view_channel: is_member # can access room
    }
  end

  defp is_member_in_channel(channel_id, provider_account_id) do
    %{"members" => members} = "#{@slack_api_base}/api/conversations.members?" <> URI.encode_query(%{token: module_config(:bot_token), channel: channel_id})
    |> Ret.HttpUtils.retry_get_until_success()
    |> Map.get(:body)
    |> Poison.decode!()

    Enum.member?(members, provider_account_id)
  end

  def fetch_display_name(
      %Ret.OAuthProvider{source: :slack, provider_account_id: provider_account_id},
      %Ret.HubBinding{community_id: _community_id}
      ) do

      %{"user" => %{"name" => name}} = "#{@slack_api_base}/api/users.info?" <> URI.encode_query(%{token: module_config(:bot_token), user: provider_account_id}) #access_token
      |> Ret.HttpUtils.retry_get_until_success()
      |> Map.get(:body)
      |> Poison.decode!()

      name
  end

  # not necessary for slack, only discord
  # Todo remove references for slack fetching_community_identifier
  def fetch_community_identifier(%Ret.OAuthProvider{source: _type, provider_account_id: _provider_account_id}) do
    "1234"
  end

  def api_request(path) do
    "#{@slack_api_base}#{path}"
    |> Ret.HttpUtils.retry_get_until_success([{"authorization", "Bot #{module_config(:bot_token)}"}])
    |> Map.get(:body)
    |> Poison.decode!()
  end

  defp get_redirect_uri(), do: RetWeb.Endpoint.url() <> "/api/v1/oauth/slack"

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end
  end
