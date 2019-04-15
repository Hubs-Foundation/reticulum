defmodule RetWeb.HubChannel do
  @moduledoc "Ret Web Channel for Hubs"

  use RetWeb, :channel

  import Canada, only: [can?: 2]

  alias Ret.{
    Hub,
    Account,
    Repo,
    RoomObject,
    OwnedFile,
    Scene,
    Storage,
    SessionStat,
    Statix,
    WebPushSubscription
  }

  alias RetWeb.{Presence}
  alias RetWeb.Api.V1.{HubView}

  @hub_preloads [
    scene: [:model_owned_file, :screenshot_owned_file, :scene_owned_file],
    scene_listing: [:model_owned_file, :screenshot_owned_file, :scene_owned_file, :scene],
    web_push_subscriptions: [],
    hub_bindings: []
  ]

  def join("hub:" <> hub_sid, %{"profile" => profile, "context" => context} = params, socket) do
    socket
    |> assign(:profile, profile)
    |> assign(:context, context)
    |> perform_join(
      hub_sid,
      params |> Map.take(["push_subscription_endpoint", "auth_token", "perms_token", "bot_access_key"])
    )
  end

  defp perform_join(socket, hub_sid, params) do
    account =
      case Ret.Guardian.resource_from_token(params["auth_token"]) do
        {:ok, %Account{} = account, _claims} -> account
        _ -> nil
      end

    hub =
      Hub
      |> Repo.get_by(hub_sid: hub_sid)
      |> Repo.preload(@hub_preloads)

    hub_requires_oauth = hub.hub_bindings |> Enum.empty?() |> Kernel.not()

    has_valid_bot_access_key = params["bot_access_key"] == Application.get_env(:ret, :bot_access_key)

    account_has_provider_for_hub = account |> Ret.Account.matching_oauth_providers(hub) |> Enum.empty?() |> Kernel.not()

    account_can_join = account |> can?(join_hub(hub))

    perms_token = params["perms_token"]

    has_perms_token = perms_token != nil

    decoded_perms = perms_token |> Ret.PermsToken.decode_and_verify()

    perms_token_can_join =
      case decoded_perms do
        {:ok, %{"join_hub" => true}} -> true
        _ -> false
      end

    {oauth_account_id, oauth_source} =
      case decoded_perms do
        {:ok, %{"oauth_account_id" => oauth_account_id, "oauth_source" => oauth_source}} ->
          {oauth_account_id, oauth_source |> String.to_atom()}

        _ ->
          {nil, nil}
      end

    params =
      params
      |> Map.merge(%{
        hub_requires_oauth: hub_requires_oauth,
        has_valid_bot_access_key: has_valid_bot_access_key,
        account_has_provider_for_hub: account_has_provider_for_hub,
        account_can_join: account_can_join,
        has_perms_token: has_perms_token,
        oauth_account_id: oauth_account_id,
        oauth_source: oauth_source,
        perms_token_can_join: perms_token_can_join
      })

    hub |> join_with_hub(account, socket, params)
  end

  def handle_in("events:entered", %{"initialOccupantCount" => occupant_count} = payload, socket) do
    socket =
      socket
      |> handle_max_occupant_update(occupant_count)
      |> handle_entered_event(payload)

    Statix.increment("ret.channels.hub.event_entered", 1)

    {:noreply, socket}
  end

  def handle_in("events:entered", payload, socket) do
    socket = socket |> handle_entered_event(payload)

    Statix.increment("ret.channels.hub.event_entered", 1)

    {:noreply, socket}
  end

  def handle_in("events:object_spawned", %{"object_type" => object_type}, socket) do
    socket = socket |> handle_object_spawned(object_type)

    Statix.increment("ret.channels.hub.objects_spawned", 1)

    {:noreply, socket}
  end

  def handle_in("events:request_support", _payload, socket) do
    hub = socket |> hub_for_socket
    Task.start_link(fn -> hub |> Ret.Support.request_support_for_hub() end)

    {:noreply, socket}
  end

  def handle_in("events:profile_updated", %{"profile" => profile}, socket) do
    socket = socket |> assign(:profile, profile) |> broadcast_presence_update
    {:noreply, socket}
  end

  def handle_in("naf" = event, %{"data" => %{"isFirstSync" => true}} = payload, socket) do
    data =
      payload["data"] |> Map.put("creator", socket.assigns.session_id) |> Map.put("owner", socket.assigns.session_id)

    payload = payload |> Map.put("data", data)
    broadcast_from!(socket, event, payload)
    {:noreply, socket}
  end

  def handle_in("naf" = event, payload, socket) do
    broadcast_from!(socket, event, payload)
    {:noreply, socket}
  end

  def handle_in("message" = event, payload, socket) do
    broadcast!(socket, event, payload |> Map.put(:session_id, socket.assigns.session_id))

    GenServer.cast(DiscordBotManager, %{
      hub_sid: socket.assigns.hub_sid,
      event: :message,
      context: socket.assigns,
      payload: payload
    })

    {:noreply, socket}
  end

  def handle_in("subscribe", %{"subscription" => subscription}, socket) do
    socket
    |> hub_for_socket
    |> WebPushSubscription.subscribe_to_hub(subscription)

    {:noreply, socket}
  end

  def handle_in("unsubscribe", %{"subscription" => subscription}, socket) do
    socket
    |> hub_for_socket
    |> WebPushSubscription.unsubscribe_from_hub(subscription)

    has_remaining_subscriptions = WebPushSubscription.endpoint_has_subscriptions?(subscription["endpoint"])

    {:reply, {:ok, %{has_remaining_subscriptions: has_remaining_subscriptions}}, socket}
  end

  def handle_in("sign_in", %{"token" => token}, socket) do
    case Ret.Guardian.resource_from_token(token) do
      {:ok, %Account{} = account, _claims} ->
        socket = Guardian.Phoenix.Socket.put_current_resource(socket, account)

        hub = socket |> hub_for_socket

        perms_token = get_perms_token(hub, account)

        {:reply, {:ok, %{perms_token: perms_token}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{message: "Sign in failed", reason: reason}}, socket}
    end
  end

  def handle_in("sign_out", _payload, socket) do
    socket = Guardian.Phoenix.Socket.put_current_resource(socket, nil)
    {:reply, {:ok, %{}}, socket}
  end

  def handle_in(
        "pin",
        %{
          "id" => object_id,
          "gltf_node" => gltf_node,
          "file_id" => file_id,
          "file_access_token" => file_access_token,
          "promotion_token" => promotion_token
        },
        socket
      ) do
    with_account(socket, fn account ->
      perform_pin!(object_id, gltf_node, account, socket)
      Storage.promote(file_id, file_access_token, promotion_token, account)
      OwnedFile.set_active(file_id, account.account_id)
    end)
  end

  def handle_in("pin", %{"id" => object_id, "gltf_node" => gltf_node}, socket) do
    with_account(socket, fn account ->
      perform_pin!(object_id, gltf_node, account, socket)
    end)
  end

  def handle_in("unpin", %{"id" => object_id, "file_id" => file_id}, socket) do
    hub = socket |> hub_for_socket

    case Guardian.Phoenix.Socket.current_resource(socket) do
      %Account{} = account ->
        RoomObject.perform_unpin(hub, object_id)
        OwnedFile.set_inactive(file_id, account.account_id)

      _ ->
        nil
    end

    {:noreply, socket}
  end

  def handle_in("unpin", %{"id" => object_id}, socket) do
    hub = socket |> hub_for_socket

    case Guardian.Phoenix.Socket.current_resource(socket) do
      %Account{} = _account ->
        RoomObject.perform_unpin(hub, object_id)

      _ ->
        nil
    end

    {:noreply, socket}
  end

  def handle_in("get_host", _args, socket) do
    hub = socket |> hub_for_socket |> Hub.ensure_host()
    {:reply, {:ok, %{host: hub.host}}, socket}
  end

  def handle_in("update_hub", payload, socket) do
    hub = socket |> hub_for_socket
    account = Guardian.Phoenix.Socket.current_resource(socket)

    if account |> can?(update_hub(hub)) do
      hub
      |> Hub.add_name_to_changeset(payload)
      |> Repo.update!()
      |> Repo.preload(@hub_preloads)
      |> broadcast_hub_refresh!(socket, ["name"])
    end

    {:noreply, socket}
  end

  def handle_in("update_scene", %{"url" => url}, socket) do
    hub = socket |> hub_for_socket |> Repo.preload([:scene, :scene_listing])
    account = Guardian.Phoenix.Socket.current_resource(socket)

    if account |> can?(update_hub(hub)) do
      endpoint_host = RetWeb.Endpoint.host()

      case url |> URI.parse() do
        %URI{host: ^endpoint_host, path: "/scenes/" <> scene_path} ->
          scene_or_listing = scene_path |> String.split("/") |> Enum.at(0) |> Scene.scene_or_scene_listing_by_sid()
          hub |> Hub.changeset_for_new_scene(scene_or_listing)

        _ ->
          hub |> Hub.changeset_for_new_environment_url(url)
      end
      |> Repo.update!()
      |> Repo.preload(@hub_preloads, force: true)
      |> broadcast_hub_refresh!(socket, ["scene"])
    end

    {:noreply, socket}
  end

  def handle_in(
        "refresh_perms_token",
        _args,
        %{assigns: %{oauth_account_id: oauth_account_id, oauth_source: oauth_source}} = socket
      )
      when oauth_account_id != nil do
    perms_token =
      socket
      |> hub_for_socket
      |> get_perms_token(%Ret.OAuthProvider{
        provider_account_id: oauth_account_id,
        source: oauth_source
      })

    {:reply, {:ok, %{perms_token: perms_token}}, socket}
  end

  def handle_in("refresh_perms_token", _args, socket) do
    account = Guardian.Phoenix.Socket.current_resource(socket)
    perms_token = socket |> hub_for_socket |> get_perms_token(account)
    {:reply, {:ok, %{perms_token: perms_token}}, socket}
  end

  def handle_in("kick", %{"session_id" => session_id}, socket) do
    account = Guardian.Phoenix.Socket.current_resource(socket)
    hub = socket |> hub_for_socket

    if account |> can?(kick_users(hub)) do
      RetWeb.Endpoint.broadcast("session:#{session_id}", "disconnect", %{})
    end

    {:noreply, socket}
  end

  def handle_in(_message, _payload, socket) do
    {:noreply, socket}
  end

  defp with_account(socket, handler) do
    case Guardian.Phoenix.Socket.current_resource(socket) do
      %Account{} = account ->
        handler.(account)
        {:reply, {:ok, %{}}, socket}

      _ ->
        # client should have signed-in at this point,
        # so if we still don't have an account, it must have been an invalid token
        {:reply, {:error, %{reason: :invalid_token}}, socket}
    end
  end

  def handle_info({:begin_tracking, session_id, _hub_sid}, socket) do
    {:ok, _} = Presence.track(socket, session_id, socket |> presence_meta_for_socket)
    push(socket, "presence_state", socket |> Presence.list())

    {:noreply, socket}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  defp perform_pin!(object_id, gltf_node, account, socket) do
    hub = socket |> hub_for_socket
    RoomObject.perform_pin!(hub, account, %{object_id: object_id, gltf_node: gltf_node})
    broadcast_pinned_media(socket, object_id, gltf_node)
  end

  def terminate(_reason, socket) do
    socket
    |> SessionStat.stat_query_for_socket()
    |> Repo.update_all(set: [ended_at: NaiveDateTime.utc_now()])

    GenServer.cast(DiscordBotManager, %{hub_sid: socket.assigns.hub_sid, event: :part, context: socket.assigns})

    :ok
  end

  defp broadcast_presence_update(socket) do
    Presence.update(socket, socket.assigns.session_id, socket |> presence_meta_for_socket)
    socket
  end

  defp broadcast_pinned_media(socket, object_id, gltf_node) do
    broadcast!(socket, "pin", %{object_id: object_id, gltf_node: gltf_node, pinned_by: socket.assigns.session_id})
  end

  # Broadcasts the full hub info as well as an (optional) list of specific fields which
  # clients should consider stale and need to be updated in client state from the new
  # hub info
  #
  # Note this doesn't necessarily mean the fields have changed.
  #
  # For example, if the scene needs to be refreshed, this message indicates that by including
  # "scene" in the list of stale fields.
  defp broadcast_hub_refresh!(hub, socket, stale_fields) do
    response =
      HubView.render("show.json", %{hub: hub})
      |> Map.put(:session_id, socket.assigns.session_id)
      |> Map.put(:stale_fields, stale_fields)

    broadcast!(socket, "hub_refresh", response)
  end

  defp presence_meta_for_socket(socket) do
    socket.assigns
    |> override_display_name(socket)
    |> Map.take([:presence, :profile, :context])
  end

  # Hubs Bot can set their own display name.
  defp override_display_name(%{hub_requires_oauth: true, has_valid_bot_access_key: true} = assigns, _socket),
    do: assigns

  # Do a direct display name lookup for OAuth users without a verified email (and thus, no Hubs account).
  defp override_display_name(
         %{hub_requires_oauth: true, oauth_source: oauth_source, oauth_account_id: oauth_account_id} = assigns,
         _socket
       )
       when not is_nil(oauth_source) and not is_nil(oauth_account_id) do
    display_name =
      Ret.HubBinding.fetch_display_name(%Ret.OAuthProvider{
        source: oauth_source,
        provider_account_id: oauth_account_id
      })

    assigns |> Map.merge(%{profile: %{"displayName" => display_name}})
  end

  # If there isn't an oauth account id on the socket, we expect the user to have an account
  defp override_display_name(
         %{hub_requires_oauth: true, hub_sid: hub_sid, oauth_account_id: oauth_account_id} = assigns,
         socket
       )
       when is_nil(oauth_account_id) do
    hub = Hub |> Repo.get_by(hub_sid: hub_sid) |> Repo.preload(:hub_bindings)
    account = Guardian.Phoenix.Socket.current_resource(socket)
    # Note: There's no way tell which oauth_provider a user would like to identify with. We're just going to pick
    # the first one for now.
    oauth_provider = account |> Account.matching_oauth_providers(hub) |> Enum.at(0)
    display_name = Ret.HubBinding.fetch_display_name(oauth_provider)
    assigns |> Map.merge(%{profile: %{"displayName" => display_name}})
  end

  # We don't override display names for unbound hubs
  defp override_display_name(%{hub_requires_oauth: false} = assigns, _socket), do: assigns

  defp join_with_hub(nil, _account, _socket, _params) do
    Statix.increment("ret.channels.hub.joins.not_found")

    {:error, %{message: "No such Hub"}}
  end

  defp join_with_hub(%Hub{entry_mode: :deny}, _account, _socket, _params) do
    {:error, %{message: "Hub no longer accessible", reason: "closed"}}
  end

  defp join_with_hub(%Hub{}, %Account{}, _socket, %{
         hub_requires_oauth: true,
         account_has_provider_for_hub: true,
         account_can_join: false
       }),
       do: deny_join()

  defp join_with_hub(%Hub{}, nil = _account, _socket, %{
         hub_requires_oauth: true,
         has_valid_bot_access_key: false,
         has_perms_token: true,
         perms_token_can_join: false
       }),
       do: deny_join()

  defp join_with_hub(%Hub{} = hub, %Account{}, _socket, %{
         hub_requires_oauth: true,
         account_has_provider_for_hub: false
       }),
       do: require_oauth(hub)

  defp join_with_hub(%Hub{} = hub, nil = _account, _socket, %{
         hub_requires_oauth: true,
         has_valid_bot_access_key: false,
         has_perms_token: false
       }),
       do: require_oauth(hub)

  defp join_with_hub(%Hub{} = hub, account, socket, params) do
    hub = hub |> Hub.ensure_valid_entry_code!() |> Hub.ensure_host()

    push_subscription_endpoint = params["push_subscription_endpoint"]

    is_push_subscribed =
      push_subscription_endpoint &&
        hub.web_push_subscriptions |> Enum.any?(&(&1.endpoint == push_subscription_endpoint))

    socket = Guardian.Phoenix.Socket.put_current_resource(socket, account)

    with socket <-
           socket
           |> assign(:hub_sid, hub.hub_sid)
           |> assign(:hub_requires_oauth, params[:hub_requires_oauth])
           |> assign(:presence, :lobby)
           |> assign(:oauth_account_id, params[:oauth_account_id])
           |> assign(:oauth_source, params[:oauth_source])
           |> assign(:has_valid_bot_access_key, params[:has_valid_bot_access_key]),
         response <- HubView.render("show.json", %{hub: hub}) do
      response = response |> Map.put(:session_id, socket.assigns.session_id)
      response = response |> Map.put(:session_token, socket.assigns.session_id |> Ret.SessionToken.token_for_session())

      response = response |> Map.put(:subscriptions, %{web_push: is_push_subscribed})

      perms_token = params["perms_token"] || get_perms_token(hub, account)

      response = response |> Map.put(:perms_token, perms_token)

      existing_stat_count =
        socket
        |> SessionStat.stat_query_for_socket()
        |> Repo.all()
        |> length

      unless existing_stat_count > 0 do
        with session_id <- socket.assigns.session_id,
             started_at <- socket.assigns.started_at,
             stat_attrs <- %{session_id: session_id, started_at: started_at},
             changeset <- %SessionStat{} |> SessionStat.changeset(stat_attrs) do
          Repo.insert(changeset)
        end
      end

      send(self(), {:begin_tracking, socket.assigns.session_id, hub.hub_sid})

      # Send join push notification if this is the first joiner
      if Presence.list(socket.topic) |> Enum.count() == 0 do
        Task.start_link(fn -> hub |> Hub.send_push_messages_for_join(push_subscription_endpoint) end)
      end

      GenServer.cast(DiscordBotManager, %{hub_sid: socket.assigns.hub_sid, event: :join, context: socket.assigns})

      Statix.increment("ret.channels.hub.joins.ok")

      {:ok, response, socket}
    end
  end

  defp require_oauth(hub) do
    oauth_info = hub.hub_bindings |> get_oauth_info(hub.hub_sid)
    {:error, %{message: "OAuth required", reason: "oauth_required", oauth_info: oauth_info}}
  end

  defp deny_join do
    {:error, %{message: "Join denied", reason: "join_denied"}}
  end

  defp get_oauth_info(hub_bindings, hub_sid) do
    hub_bindings
    |> Enum.map(
      &case &1 do
        %{type: :discord} -> %{type: :discord, url: Ret.DiscordClient.get_oauth_url(hub_sid)}
      end
    )
  end

  defp get_perms_token(hub, %Ret.OAuthProvider{provider_account_id: provider_account_id, source: source} = account) do
    hub
    |> Hub.perms_for_account(account)
    |> Map.put(:oauth_account_id, provider_account_id)
    |> Map.put(:oauth_source, source)
    |> Map.put(:hub_id, hub.hub_sid)
    |> Ret.PermsToken.token_for_perms()
  end

  defp get_perms_token(hub, account) do
    account_id = if account, do: account.account_id, else: nil

    hub
    |> Hub.perms_for_account(account)
    |> Account.add_global_perms_for_account(account)
    |> Map.put(:account_id, account_id |> to_string)
    |> Map.put(:hub_id, hub.hub_sid)
    |> Ret.PermsToken.token_for_perms()
  end

  defp handle_entered_event(socket, payload) do
    stat_attributes = [entered_event_payload: payload, entered_event_received_at: NaiveDateTime.utc_now()]

    # Flip context to have HMD if entered with display type
    socket =
      with %{"entryDisplayType" => display} when is_binary(display) and display != "Screen" <- payload,
           %{context: context} when is_map(context) <- socket.assigns do
        socket |> assign(:context, context |> Map.put("hmd", true))
      else
        _ -> socket
      end

    socket
    |> SessionStat.stat_query_for_socket()
    |> Repo.update_all(set: stat_attributes)

    socket |> assign(:presence, :room) |> broadcast_presence_update
  end

  defp handle_max_occupant_update(socket, occupant_count) do
    socket
    |> hub_for_socket
    |> Hub.changeset_for_new_seen_occupant_count(occupant_count)
    |> Repo.update!()

    socket
  end

  defp handle_object_spawned(socket, object_type) do
    socket
    |> hub_for_socket
    |> Hub.changeset_for_new_spawned_object_type(object_type)
    |> Repo.update!()

    socket
  end

  defp hub_for_socket(socket) do
    Repo.get_by(Hub, hub_sid: socket.assigns.hub_sid) |> Repo.preload(:hub_bindings)
  end
end
