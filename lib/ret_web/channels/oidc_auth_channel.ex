defmodule RetWeb.OIDCAuthChannel do
  @moduledoc "Ret Web Channel for OpenID Connect Authentication"

  require Logger

  use RetWeb, :channel
  import Canada, only: [can?: 2]

  alias Ret.{Account, OAuthToken, RemoteOIDCClient, RemoteOIDCToken, AppConfig}

  intercept(["auth_credentials"])

  # Intersection of possible values for JSON signing https://www.rfc-editor.org/rfc/rfc7518#section-3.1
  # and algorithms supported by JOSE https://hexdocs.pm/jose/JOSE.JWS.html#module-algorithms
  @supported_algorithms ["HS256", "HS384", "HS512", "RS256", "RS384", "RS512", "ES256", "ES384", "ES512", "PS256", "PS384", "PS512"]

  def join("oidc:" <> _topic_key, _payload, socket) do
    # Expire channel in 5 minutes
    Process.send_after(self(), :channel_expired, 60 * 1000 * 5)

    # Rate limit joins to reduce attack surface
    :timer.sleep(500)

    {:ok, %{session_id: socket.assigns.session_id}, socket}
  end

  defp get_redirect_uri(), do: RetWeb.Endpoint.url() <> "/verify"

  defp get_authorize_url(state, nonce) do
    RemoteOIDCClient.get_auth_endpoint() <> "?" <>
      URI.encode_query(%{
        response_type: "code",
        response_mode: "query",
        client_id: RemoteOIDCClient.get_client_id(),
        scope: RemoteOIDCClient.get_scopes(),
        state: state,
        nonce: nonce,
        redirect_uri: get_redirect_uri()
      })
  end

  defp fetch_user_info(access_token) do
    # user info endpoint is optional
    case RemoteOIDCClient.get_userinfo_endpoint() do
      nil -> nil
      url -> url
        |> Ret.HttpUtils.retry_get_until_success(headers: [{"authorization", "Bearer #{access_token}"}])
        |> Map.get(:body)
        |> Poison.decode!()
    end
  end

  def handle_in("auth_request", _payload, socket) do
    if Map.get(socket.assigns, :nonce) do
      {:reply, {:error, "Already started an auth request on this session"}, socket}
    else
      if AppConfig.get_config_bool("auth|use_oidc") do
        "oidc:" <> topic_key = socket.topic
        oidc_state = Ret.OAuthToken.token_for_oidc_request(topic_key, socket.assigns.session_id)
        nonce = SecureRandom.uuid()
        authorize_url = get_authorize_url(oidc_state, nonce)

        socket = socket |> assign(:nonce, nonce)

        {:reply, {:ok, %{authorize_url: authorize_url}}, socket}
      else
        {:reply, {:error, %{message: "OpenID Connect not enabled"}}, socket}
      end
    end
  end

  def handle_in("auth_verified", %{"token" => code, "payload" => state}, socket) do
    Process.send_after(self(), :close_channel, 1000 * 5)

    # Slow down any brute force attacks
    :timer.sleep(500)

    "oidc:" <> expected_topic_key = socket.topic

    with {:ok,
          %{
            "topic_key" => topic_key,
            "session_id" => session_id,
            "aud" => "ret_oidc"
          }}
         when topic_key == expected_topic_key <- OAuthToken.decode_and_verify(state),
         {:ok,
          %{
            "access_token" => access_token,
            "id_token" => raw_id_token
          }} <- fetch_oidc_tokens(code),
         {:ok,
          %{
            "aud" => _aud,
            "nonce" => nonce,
            "sub" => remote_user_id
          } = id_token} <- RemoteOIDCToken.decode_and_verify(raw_id_token, %{}, allowed_algos: @supported_algorithms) do

      # Searchable identifier is unique to the OIDC provider and user
      identifier_hash = RemoteOIDCClient.get_openid_configuration_uri() <> "#" <> remote_user_id
        |> Account.identifier_hash_for_email()

      # The OIDC user info endpoint is optional, so if it missing we assume info will be in the id token instead
      # and filter for just the permitted claims
      all_claims = fetch_user_info(access_token) || id_token
      permitted_claims = RemoteOIDCClient.get_permitted_claims()
      filtered_claims = :maps.filter(fn key, _val -> key in permitted_claims end, all_claims)

      broadcast_credentials_and_payload(
        identifier_hash,
        %{oidc: filtered_claims},
        %{session_id: session_id, nonce: nonce},
        socket
      )

      {:reply, :ok, socket}
    else
      {:error, error} ->
        # Error messages from Guardian are very limited https://github.com/ueberauth/guardian/issues/711
        Logger.warn("OIDC error: #{inspect(error)}")
        {:reply, {:error, %{message: "error fetching or verifying token"}}, socket}
    end
  end

  def handle_in(_event, _payload, socket) do
    {:noreply, socket}
  end

  defp fetch_oidc_tokens(oauth_code) do
    body =
      {:form,
       [
          client_id: RemoteOIDCClient.get_client_id(),
          client_secret: RemoteOIDCClient.get_client_secret(),
          grant_type: "authorization_code",
          redirect_uri: get_redirect_uri(),
          code: oauth_code,
          scope: RemoteOIDCClient.get_scopes()
      ]}

    options = [
      headers: [{"content-type", "application/x-www-form-urlencoded"}]
    ]

    case Ret.HttpUtils.retry_post_until_success(RemoteOIDCClient.get_token_endpoint(), body, options) do
      %HTTPoison.Response{body: body} -> body |> Poison.decode()
      _ -> {:error, "Failed to fetch tokens"}
    end
  end

  def handle_info(:close_channel, socket) do
    GenServer.cast(self(), :close)
    {:noreply, socket}
  end

  def handle_info(:channel_expired, socket) do
    GenServer.cast(self(), :close)
    {:noreply, socket}
  end

  # Only send credentials back down to the original socket that started the request
  def handle_out(
        "auth_credentials" = event,
        %{credentials: credentials, user_info: user_info, verification_info: verification_info},
        socket
      ) do
    Process.send_after(self(), :close_channel, 1000 * 5)

    if Map.get(socket.assigns, :session_id) == Map.get(verification_info, :session_id) and
         Map.get(socket.assigns, :nonce) == Map.get(verification_info, :nonce) do
      push(socket, event, %{credentials: credentials, user_info: user_info})
    end

    {:noreply, socket}
  end

  defp broadcast_credentials_and_payload(nil, _user_info, _verification_info, _socket), do: nil

  defp broadcast_credentials_and_payload(identifier_hash, user_info, verification_info, socket) do
    account_creation_enabled = can?(nil, create_account(nil))
    account = identifier_hash |> Account.account_for_login_identifier_hash(account_creation_enabled)
    credentials = account |> Account.credentials_for_account()

    broadcast!(socket, "auth_credentials", %{
      credentials: credentials,
      user_info: user_info,
      verification_info: verification_info
    })
  end
end
