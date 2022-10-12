defmodule RetWeb.RetChannel do
  @moduledoc "Global comms channel for reticulum cluster"

  use RetWeb, :channel

  alias Ret.{Account, Statix}
  alias RetWeb.{Presence}

  intercept(["presence_diff"])

  def join("ret", %{"hub_id" => hub_id, "token" => token}, socket) do
    case Ret.Guardian.resource_from_token(token) do
      {:ok, %Account{} = account, _claims} ->
        socket
        |> Guardian.Phoenix.Socket.put_current_resource(account)
        |> handle_join(hub_id)

      {:error, reason} ->
        {:error, %{message: "Sign in failed", reason: reason}}
    end
  end

  def join("ret", %{"hub_id" => hub_id}, socket) do
    socket |> handle_join(hub_id)
  end

  def handle_in("change_hub", %{"hub_id" => hub_id}, socket) do
    {:ok, _} = Presence.update(socket, socket.assigns.session_id, %{hub_id: hub_id})
    {:noreply, socket}
  end

  def handle_in("refresh_perms_token", _params, socket) do
    account = Guardian.Phoenix.Socket.current_resource(socket)

    perms = Account.get_global_perms_for_account(account)

    perms =
      if account do
        perms |> Map.put(:account_id, account.account_id)
      else
        perms
      end

    perms_token = perms |> Ret.PermsToken.token_for_perms()

    {:reply, {:ok, %{perms_token: perms_token}}, socket}
  end

  def handle_info({:begin_tracking, session_id, hub_id}, socket) do
    {:ok, _} = Presence.track(socket, session_id, %{hub_id: hub_id})
    {:noreply, socket}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  def handle_out("presence_diff", _payload, socket) do
    # Do not send presence updates on this channel, for privacy reasons
    {:noreply, socket}
  end

  defp handle_join(socket, hub_id) do
    Statix.increment("ret.channels.ret.joins.ok")
    vapid_public_key = Application.get_env(:web_push_encryption, :vapid_details)[:public_key]

    send(self(), {:begin_tracking, socket.assigns.session_id, hub_id})
    {:ok, %{vapid_public_key: vapid_public_key, session_id: socket.assigns.session_id}, socket}
  end
end
