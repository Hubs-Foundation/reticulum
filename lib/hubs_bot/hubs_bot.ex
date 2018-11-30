defmodule HubsBot do
  use Supervisor
  alias Alchemy.Client
  alias Alchemy.Embed

  defmodule BotState do
    use GenServer

    def start_link(_opts) do
      GenServer.start_link(__MODULE__, :ok, name: BotState)
    end

    def set_channel_mappings(channels_by_hub, hubs_by_channel) do
      GenServer.cast(BotState, {:set_channel_mapping, channels_by_hub, hubs_by_channel})
    end

    def get_channels_for_hub(hub_id) do
      GenServer.call(BotState, {:get_channels_for_hub, hub_id})
    end

    def get_hubs_for_channel(channel_id) do
      GenServer.call(BotState, {:get_hubs_for_channel, channel_id})
    end

    def init(:ok) do
      {:ok, %{}}
    end

    def handle_call({:get_channels_for_hub, hub_id}, _from, state) do
      {:reply, state |> get_in([:channels_by_hub, hub_id]), state}
    end

    def handle_call({:get_hubs_for_channel, channel_id}, _from, state) do
      {:reply, state |> get_in([:hubs_by_channel, channel_id]), state}
    end

    def handle_cast({:set_channel_mapping, channels_by_hub, hubs_by_channel}, state) do
      {:noreply,
       state
       |> Map.put(:channels_by_hub, channels_by_hub)
       |> Map.put(:hubs_by_channel, hubs_by_channel)}
    end
  end

  defmodule HubsCommands do
    use Alchemy.Cogs
    require Alchemy.Embed, as: Embed

    Cogs.def duck do
      Cogs.say("Quack :duck:")
    end

    Cogs.def bound do
      case HubsBot.BotState.get_hubs_for_channel(message.channel_id) do
        hub_ids = [_ | _] ->
          Cogs.say("This channel is bound to #{Enum.join(hub_ids, ", ")}")

        _ ->
          Cogs.say("No hubs bound to this channel")
      end
    end
  end

  defmodule HubsEvents do
    use Alchemy.Events

    Events.on_channel_update(:on_channel_update)
    Events.on_ready(:on_ready)
    Events.on_message(:on_message)

    def on_channel_update(channel) do
      IO.inspect("#{channel.name} was updated, topic: #{channel.topic}")
      update_bound_channels()
    end

    def on_ready(_shard, _total_shards) do
      update_bound_channels()
    end

    def on_message(msg) do
      if hub_ids = !msg.author.bot && HubsBot.BotState.get_hubs_for_channel(msg.channel_id) do
        hub_ids |> Enum.each(&broadcast_to_hubs(&1, msg))
      end
    end

    def broadcast_to_hubs(hub_id, msg) do
      IO.inspect(msg)

      RetWeb.Endpoint.broadcast!("hub:#{hub_id}", "message", %{
        type: "chat",
        body: msg.content,
        from: "#{msg.author.username}##{msg.author.discriminator}"
      })
    end

    ###

    @hub_url_regex ~r"https?://(?:hubs.local(?:\:\d+)?|hubs.mozilla.com)/(\w+)/?\S*"
    def update_bound_channels do
      bound_channels =
        for guild <- elem(Alchemy.Client.get_current_guilds(), 1),
            channel <- elem(Alchemy.Client.get_channels(guild.id), 1),
            topic = channel.topic,
            matches = Regex.scan(@hub_url_regex, channel.topic),
            [_, hub_id] <- matches do
          {hub_id, channel.id}
        end

      channels_by_hub =
        bound_channels |> Enum.group_by(&elem(&1, 0), &elem(&1, 1)) |> IO.inspect()

      hubs_by_channel =
        bound_channels |> Enum.group_by(&elem(&1, 1), &elem(&1, 0)) |> IO.inspect()

      HubsBot.BotState.set_channel_mappings(channels_by_hub, hubs_by_channel)
    end
  end

  def on_hubs_event(hub_id, event, context, payload \\ %{}) do
    if channel_ids = HubsBot.BotState.get_channels_for_hub(hub_id) do
      do_on_hubs_event(channel_ids, hub_id, event, context, payload)
    end
  end

  def do_on_hubs_event(
        channel_ids,
        hub_id,
        :message,
        %{:profile => %{"displayName" => username}},
        payload
      ) do
    Enum.each(
      channel_ids,
      &broadcast_message_to_discord(&1, username, payload |> content_for_payload(username))
    )
  end

  def do_on_hubs_event(
        channel_ids,
        hub_id,
        event,
        %{:profile => %{"displayName" => username}},
        payload
      )
      when event in [:join, :part] do
    Enum.each(channel_ids, &broadcast_user_event_to_discord(&1, username, event))
  end

  defp content_for_payload(%{"type" => "chat"} = payload, username),
    do: [content: payload["body"]]

  defp content_for_payload(%{"type" => "spawn"} = payload, username) do
    [
      embeds: [
        %Embed{}
        |> Embed.color(0xFF3464)
        |> Embed.author(
          name: "#{username} took a photo",
          icon_url: "https://blog.mozvr.com/content/images/2018/04/image--1-.png"
        )
        |> Embed.image(
          "https://uploads-prod.reticulum.io/files/9f3cda3a-d445-4601-970c-6b0e4b494113.png?token=b9cf857b51565787bcace71389f1d8a2"
        )
        # |> Embed.image(payload["body"]["src"])
      ]
    ]
  end

  def broadcast_message_to_discord(channel_id, username, options \\ []) do
    {:ok, [hook | _]} = Alchemy.Webhook.in_channel(channel_id)

    Alchemy.Webhook.send(
      hook,
      {:username, username},
      options ++
        [
          avatar_url: "https://blog.mozvr.com/content/images/2018/04/image--1-.png"
        ]
    )
  end

  def broadcast_user_event_to_discord(channel_id, username, event) do
    embed =
      case event do
        :join ->
          %Embed{}
          |> Embed.color(0x97F897)
          |> Embed.author(
            name: "#{username} joined",
            icon_url: "https://blog.mozvr.com/content/images/2018/04/image--1-.png"
          )

        :part ->
          %Embed{}
          |> Embed.color(0xF89797)
          |> Embed.author(
            name: "#{username} left",
            icon_url: "https://blog.mozvr.com/content/images/2018/04/image--1-.png"
          )
      end

    Client.send_message(channel_id, "", embed: embed)
  end

  def start_link(args, options \\ []) do
    result = Supervisor.start_link(__MODULE__, args, options)
    with {:ok, _} <- result do
      use HubsCommands
      use HubsEvents
    end
    result
  end

  def init(options \\ []) do
    children = [
      supervisor(Alchemy.Client, [module_config(:token), options]),
      BotState
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end
end
