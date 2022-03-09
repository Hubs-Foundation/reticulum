defmodule Ret.SlackClient do
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

  def fetch_access_token(oauth_code) do
    body = {
      :form,
      [
        client_id: module_config(:client_id),
        client_secret: module_config(:client_secret),
        code: oauth_code,
        redirect_uri: get_redirect_uri()
      ]
    }

    %{"authed_user" => authed_user} =
      "#{@slack_api_base}/api/oauth.v2.access"
      |> Ret.HttpUtils.retry_post_until_success(body, headers: [{"content-type", "application/x-www-form-urlencoded"}])
      |> Map.get(:body)
      |> Poison.decode!()

    Map.get(authed_user, "access_token")
  end

  def fetch_user_info(access_token) do
    %{"user" => user} =
      ("#{@slack_api_base}/api/users.identity?" <> URI.encode_query(%{token: access_token}))
      |> Ret.HttpUtils.retry_get_until_success()
      |> Map.get(:body)
      |> Poison.decode!()

    # Slack users are always email verified before joining a slack workspace
    # Therefore, set verified to true
    user |> Map.put("verified", true)
  end

  def has_permission?(nil, _, _), do: false

  def has_permission?(%Ret.OAuthProvider{} = oauth_provider, %Ret.HubBinding{} = hub_binding, permission) do
    oauth_provider.provider_account_id |> has_permission?(hub_binding, permission)
  end

  def has_permission?(provider_account_id, %Ret.HubBinding{} = hub_binding, permission)
      when is_binary(provider_account_id) do
    permissions = get_permissions(hub_binding.channel_id, provider_account_id)

    permissions[permission]
  end

  defp get_permissions(channel_id, provider_account_id) do
    # Specific channel permissions
    is_member = is_member_in_channel(channel_id, provider_account_id)

    %{
      # change scene
      manage_channels: is_member,
      # moderate room
      kick_members: is_member,
      # can access room
      view_channel: is_member
    }
  end

  defp is_member_in_channel(channel_id, provider_account_id) do
    %{"members" => members} =
      case Cachex.fetch(
             :slack_api,
             "/api/conversations.members?" <> URI.encode_query(%{channel: channel_id})
           ) do
        {status, result} when status in [:commit, :ok] -> result
      end

    Enum.member?(members, provider_account_id)
  end

  def fetch_display_name(
        %Ret.OAuthProvider{source: :slack, provider_account_id: provider_account_id},
        %Ret.HubBinding{community_id: _community_id}
      ) do
    %{"user" => %{"name" => name}} =
      case Cachex.fetch(
             :slack_api,
             "/api/users.info?" <> URI.encode_query(%{user: provider_account_id})
           ) do
        {status, result} when status in [:commit, :ok] -> result
      end

    name
  end

  def fetch_community_identifier(%Ret.OAuthProvider{source: _type, provider_account_id: provider_account_id}) do
    %{"user" => %{"real_name" => real_name}} =
      case Cachex.fetch(
             :slack_api,
             "/api/users.info?" <> URI.encode_query(%{user: provider_account_id})
           ) do
        {status, result} when status in [:commit, :ok] -> result
      end

    real_name
  end

  def api_request(path) do
    "#{@slack_api_base}#{path}"
    |> Ret.HttpUtils.retry_get_until_success(headers: [{"authorization", "Bearer #{module_config(:bot_token)}"}])
    |> Map.get(:body)
    |> Poison.decode!()
  end

  defp get_redirect_uri(), do: RetWeb.Endpoint.url() <> "/api/v1/oauth/slack"

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end
end
