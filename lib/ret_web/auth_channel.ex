defmodule RetWeb.AuthChannel do
  @moduledoc "Ret Web Channel for Authentication"

  use RetWeb, :channel

  alias Ret.{Statix, LoginToken, Repo}
  alias RetWeb.{Presence}

  intercept(["link_response"])

  def join("auth:" <> topic_key = topic, _payload, socket) do
    # Expire channel in 5 minutes
    Process.send_after(self(), :channel_expired, 60 * 1000 * 5)
    socket = socket |> assign(:topic, topic)

    # Rate limit joins to reduce attack surface
    :timer.sleep(500)

    Statix.increment("ret.channels.auth.joins.ok")
    {:ok, "{}", socket}
  end

  def handle_in("auth_request", %{"email" => email}, socket) do
    if !Map.get(socket.assigns, :used) do
      socket = socket |> assign(:used, true)

      # Create token + send email
      token =
        %LoginToken{}
        |> LoginToken.changeset(%{email: email})
        |> Repo.insert!()
        |> Map.get(:token)

      signin_args = %{topic: socket.assigns.topic, token: token}
      RetWeb.Email.auth_email(email, signin_args) |> Ret.Mailer.deliver_now()

      {:noreply, socket}
    else
      {:reply, {:error, "Already sent"}, socket}
    end
  end

  def handle_in("auth_verified" = event, %{"token" => token}, socket) do
    # Look up token, if found, create or fetch account, remove token, generate JWT, and broadcast it into the channel
    Process.send_after(self(), :close_channel, 1000 * 5)
    jwt = "foo"

    broadcast!(socket, event, %{credentials: jwt})

    {:noreply, socket}
  end

  def handle_in(_event, _payload, socket) do
    {:noreply, socket}
  end

  def handle_info(:close_channel, socket) do
    GenServer.cast(self(), :close)
    {:noreply, socket}
  end
end
