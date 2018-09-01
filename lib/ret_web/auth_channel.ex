defmodule RetWeb.AuthChannel do
  @moduledoc "Ret Web Channel for Authentication"

  use RetWeb, :channel

  alias Ret.{Statix, LoginToken, Account}

  intercept(["link_response"])

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

    token |> LoginToken.valid_email_for_token() |> broadcast_credentials_for_email(socket)
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

  defp broadcast_credentials_for_email(nil, _socket), do: nil

  defp broadcast_credentials_for_email(email, socket) do
    credentials = email |> Account.credentials_for_email()
    broadcast!(socket, "auth_credentials", %{credentials: credentials})
  end
end
