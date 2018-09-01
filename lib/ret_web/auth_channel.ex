defmodule RetWeb.AuthChannel do
  @moduledoc "Ret Web Channel for Authentication"

  use RetWeb, :channel

  alias Ret.{Statix, LoginToken, Account}

  intercept(["auth_credentials"])

  def join("auth:" <> _topic_key, _payload, socket) do
    # Expire channel in 5 minutes
    Process.send_after(self(), :channel_expired, 60 * 1000 * 5)

    # Rate limit joins to reduce attack surface
    :timer.sleep(500)

    Statix.increment("ret.channels.auth.joins.ok")
    {:ok, "{}", socket}
  end

  def handle_in("auth_request", %{"email" => email}, socket) do
    if !Map.get(socket.assigns, :used) do
      socket = socket |> assign(:used, true)

      # Create token + send email
      token = LoginToken.new_token_for_email(email)
      signin_args = %{topic: socket.topic, token: token}

      RetWeb.Email.auth_email(email, signin_args) |> Ret.Mailer.deliver_now()

      {:noreply, socket}
    else
      {:reply, {:error, "Already sent"}, socket}
    end
  end

  def handle_in("auth_verified", %{"token" => token}, socket) do
    Process.send_after(self(), :close_channel, 1000 * 5)

    # Slow down token guessing
    :timer.sleep(500)

    token
    |> LoginToken.identifier_hash_for_token()
    |> broadcast_credentials_for_identifier_hash(socket)

    LoginToken.expire!(token)

    {:noreply, socket}
  end

  def handle_in(_event, _payload, socket) do
    {:noreply, socket}
  end

  def handle_info(:close_channel, socket) do
    GenServer.cast(self(), :close)
    {:noreply, socket}
  end

  def handle_out("auth_credentials" = event, payload, socket) do
    Process.send_after(self(), :close_channel, 1000 * 5)
    push(socket, event, payload)
    {:noreply, socket}
  end

  defp broadcast_credentials_for_identifier_hash(nil, _socket), do: nil

  defp broadcast_credentials_for_identifier_hash(hash, socket) do
    credentials = hash |> Account.credentials_for_identifier_hash()
    broadcast!(socket, "auth_credentials", %{credentials: credentials})
  end
end
