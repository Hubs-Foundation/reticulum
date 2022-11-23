defmodule RetWeb.AuthChannel do
  @moduledoc "Ret Web Channel for Authentication"

  use RetWeb, :channel
  import Canada, only: [can?: 2]

  alias Ret.{Statix, LoginToken, Account, Crypto}

  intercept(["auth_credentials"])

  def join("auth:" <> _topic_key, _payload, socket) do
    # Expire channel in 5 minutes
    Process.send_after(self(), :channel_expired, 60 * 1000 * 5)

    # Rate limit joins to reduce attack surface
    :timer.sleep(500)

    Statix.increment("ret.channels.auth.joins.ok")
    {:ok, %{session_id: socket.assigns.session_id}, socket}
  end

  def handle_in("auth_request", %{"email" => email, "origin" => origin}, socket) do
    if !Map.get(socket.assigns, :used) do
      socket = socket |> assign(:used, true)

      account = email |> Account.account_for_email()
      account_disabled = account && account.state == :disabled

      if !account_disabled && (can?(nil, create_account(nil)) || !!account) do
        # Create token + send email
        %LoginToken{token: token, payload_key: payload_key} =
          LoginToken.new_login_token_for_email(email)

        encrypted_payload =
          %{"email" => email}
          |> Poison.encode!()
          |> Crypto.encrypt(payload_key)
          |> :base64.encode()

        signin_args = %{
          auth_topic: socket.topic,
          auth_token: token,
          auth_origin: origin,
          auth_payload: encrypted_payload
        }

        Statix.increment("ret.emails.auth.attempted", 1)

        if RetWeb.Email.enabled?() do
          RetWeb.Email.auth_email(email, signin_args) |> Ret.Mailer.deliver_now()
        end

        Statix.increment("ret.emails.auth.sent", 1)
      end

      {:noreply, socket}
    else
      {:reply, {:error, "Already sent"}, socket}
    end
  end

  def handle_in("auth_verified", %{"token" => token, "payload" => auth_payload}, socket) do
    Process.send_after(self(), :close_channel, 1000 * 5)

    # Slow down token guessing
    :timer.sleep(500)

    case LoginToken.lookup_by_token(token) do
      %LoginToken{identifier_hash: identifier_hash, payload_key: payload_key} ->
        decrypted_payload =
          auth_payload |> :base64.decode() |> Ret.Crypto.decrypt(payload_key) |> Poison.decode!()

        broadcast_credentials_and_payload(identifier_hash, decrypted_payload, socket)

        LoginToken.expire(token)

      _ ->
        GenServer.cast(self(), :close)
    end

    {:noreply, socket}
  end

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

  def handle_out("auth_credentials" = event, payload, socket) do
    Process.send_after(self(), :close_channel, 1000 * 5)
    push(socket, event, payload)
    {:noreply, socket}
  end

  defp broadcast_credentials_and_payload(nil, _payload, _socket), do: nil

  defp broadcast_credentials_and_payload(identifier_hash, payload, socket) do
    account =
      identifier_hash |> Account.account_for_login_identifier_hash(can?(nil, create_account(nil)))

    credentials = account |> Account.credentials_for_account()
    broadcast!(socket, "auth_credentials", %{credentials: credentials, payload: payload})
  end
end
