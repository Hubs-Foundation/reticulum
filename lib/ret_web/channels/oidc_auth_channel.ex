defmodule RetWeb.OIDCAuthChannel do
  @moduledoc "Ret Web Channel for OIDC Authentication"

  use RetWeb, :channel
  import Canada, only: [can?: 2]

  alias Ret.{Statix, Account, OAuthToken}

  intercept(["auth_credentials"])

  def join("oidc:" <> _topic_key, _payload, socket) do
    # Expire channel in 5 minutes
    Process.send_after(self(), :channel_expired, 60 * 1000 * 5)

    # Rate limit joins to reduce attack surface
    :timer.sleep(500)

    Statix.increment("ret.channels.oidc.joins.ok")
    {:ok, %{session_id: socket.assigns.session_id}, socket}
  end

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end

  defp get_redirect_uri(), do: RetWeb.Endpoint.url() <> "/verify"

  defp get_authorize_url(state, nonce) do
    "#{module_config(:endpoint)}authorize?" <>
      URI.encode_query(%{
        response_type: "code",
        response_mode: "query",
        client_id: module_config(:client_id),
        scope: module_config(:scopes),
        state: state,
        nonce: nonce,
        redirect_uri: get_redirect_uri()
      })
  end

  def handle_in("auth_request", _payload, socket) do
    if Map.get(socket.assigns, :nonce) do
      {:reply, {:error, "Already started an auth request on this session"}, socket}
    else
      "oidc:" <> topic_key = socket.topic
      oidc_state = Ret.OAuthToken.token_for_oidc_request(topic_key, socket.assigns.session_id)
      nonce = SecureRandom.uuid()
      authorize_url = get_authorize_url(oidc_state, nonce)

      socket = socket |> assign(:nonce, nonce)

      IO.inspect("Started oauth flow with oidc_state #{oidc_state}, authorize_url: #{authorize_url}")
      {:reply, {:ok, %{authorize_url: authorize_url}}, socket}
    end
  end

  def handle_in("auth_verified", %{"token" => code, "payload" => state}, socket) do
    Process.send_after(self(), :close_channel, 1000 * 5)

    IO.inspect("Verify OIDC auth!!!!!")

    # Slow down token guessing
    :timer.sleep(500)

    "oidc:" <> expected_topic_key = socket.topic

    # TODO since we already have session_id secured by a token on the other end using a JWT for state may be overkill
    case OAuthToken.decode_and_verify(state) do
      {:ok,
       %{
         "topic_key" => topic_key,
         "session_id" => session_id,
         "aud" => "ret_oidc"
       }}
      when topic_key == expected_topic_key ->
        %{
          "access_token" => access_token,
          "id_token" => raw_id_token
        } = fetch_oidc_access_token(code)

        # TODO lookup pubkey by kid in header
        %JOSE.JWS{fields: %{"kid" => kid}} = JOSE.JWT.peek_protected(raw_id_token)
        IO.inspect(kid)

        pub_key = module_config(:verification_key) |> JOSE.JWK.from_pem()

        case JOSE.JWT.verify_strict(pub_key, module_config(:allowed_algos), raw_id_token)
             |> IO.inspect() do
          {true,
           %JOSE.JWT{
             fields: %{
               "aud" => _aud,
               "nonce" => nonce,
               "preferred_username" => remote_username,
               "sub" => remote_user_id
             }
           }, _jws} ->
            # TODO we may want to verify some more fields like issuer and expiration time

            # %{"sub" => remote_user_id, "preferred_username" => remote_username} =
            #   fetch_oidc_user_info(access_token) |> IO.inspect()

            broadcast_credentials_and_payload(
              remote_user_id,
              %{email: remote_username},
              %{session_id: session_id, nonce: nonce},
              socket
            )

            {:reply, :ok, socket}

          {false, _jwt, _jws} ->
            {:reply, {:error, %{msg: "invalid OIDC token from endpoint"}}, socket}

          {:error, _} ->
            {:reply, {:error, %{msg: "error verifying token"}}, socket}
        end

      # TODO we may want to be less specific about errors
      {:ok, _} ->
        {:reply, {:error, %{msg: "Invalid topic key"}}, socket}

      {:error, error} ->
        {:reply, {:error, error}, socket}
    end
  end

  def fetch_oidc_access_token(oauth_code) do
    body = {
      :form,
      [
        client_id: module_config(:client_id),
        client_secret: module_config(:client_secret),
        grant_type: "authorization_code",
        redirect_uri: get_redirect_uri(),
        code: oauth_code,
        scope: module_config(:scopes)
      ]
    }

    # todo handle error response
    "#{module_config(:endpoint)}token"
    |> Ret.HttpUtils.retry_post_until_success(body, [{"content-type", "application/x-www-form-urlencoded"}])
    |> Map.get(:body)
    |> Poison.decode!()
  end

  # def fetch_oidc_user_info(access_token) do
  #   "#{module_config(:endpoint)}userinfo"
  #   |> Ret.HttpUtils.retry_get_until_success([{"authorization", "Bearer #{access_token}"}])
  #   |> Map.get(:body)
  #   |> Poison.decode!()
  #   |> IO.inspect()
  # end

  def handle_in(_event, _payload, socket) do
    {:noreply, socket}
  end

  def handle_info(:close_channel, socket) do
    GenServer.cast(self(), :close)
    {:noreply, socket}
  end

  def handle_info(:channel_expired, socket) do
    GenServer.cast(self(), :close)
    {:noreply, socket}
  end

  def handle_out(
        "auth_credentials" = event,
        %{credentials: credentials, user_info: user_info, verification_info: verification_info},
        socket
      ) do
    Process.send_after(self(), :close_channel, 1000 * 5)
    IO.inspect("checking creds")
    IO.inspect(socket)
    IO.inspect(verification_info)

    if Map.get(socket.assigns, :session_id) == Map.get(verification_info, :session_id) and
         Map.get(socket.assigns, :nonce) == Map.get(verification_info, :nonce) do
      IO.inspect("sending creds")
      push(socket, event, %{credentials: credentials, user_info: user_info})
    end

    {:noreply, socket}
  end

  defp broadcast_credentials_and_payload(nil, _user_info, _verification_info, _socket), do: nil

  defp broadcast_credentials_and_payload(identifier_hash, user_info, verification_info, socket) do
    account_creation_enabled = can?(nil, create_account())
    account = identifier_hash |> Account.account_for_login_identifier_hash(account_creation_enabled)
    credentials = account |> Account.credentials_for_account()

    broadcast!(socket, "auth_credentials", %{
      credentials: credentials,
      user_info: user_info,
      verification_info: verification_info
    })
  end
end
