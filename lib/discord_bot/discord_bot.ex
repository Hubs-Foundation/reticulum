defmodule DiscordBot do
  use Supervisor
  alias Alchemy.Client
  alias Alchemy.Embed

  defmodule HubsCommands do
    use Alchemy.Cogs
    require Alchemy.Embed, as: Embed

    Cogs.def duck do
      Cogs.say("Quack :duck:")
    end

    Cogs.def bound do
      case Cachex.get!(:discord_bot_state, "hubs_for_channel")[message.channel_id] do
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
      if hub_ids = !msg.author.bot && Cachex.get!(:discord_bot_state, "hubs_for_channel")[msg.channel_id] do
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

    def update_bound_channels do
      host_clauses = DiscordBot.module_config(:hostnames) |> Enum.map(&("#{&1}(?:\\:\\d+)?")) |> Enum.join("|")
      {:ok, hub_url_regex} = Regex.compile("https?://(?:#{host_clauses})/(\\w+)/?\\S*")

      bound_channels =
        for guild <- elem(Alchemy.Client.get_current_guilds(), 1),
            channel <- elem(Alchemy.Client.get_channels(guild.id), 1),
            topic = channel.topic,
            matches = Regex.scan(hub_url_regex, topic),
            [_, hub_id] <- matches do
          {hub_id, channel.id}
        end

      channels_by_hub =
        bound_channels |> Enum.group_by(&elem(&1, 0), &elem(&1, 1)) |> IO.inspect()

      hubs_by_channel =
        bound_channels |> Enum.group_by(&elem(&1, 1), &elem(&1, 0)) |> IO.inspect()

      Cachex.transaction!(:discord_bot_state, ["hubs_for_channel", "channels_for_hub"], fn(cache) ->
        Cachex.put!(cache, "hubs_for_channel", hubs_by_channel)
        Cachex.put!(cache, "channels_for_hub", channels_by_hub)
      end)
    end
  end

  def on_hubs_event(hub_id, event, context, payload \\ %{}) do
    if channel_ids = Cachex.get!(:discord_bot_state, "channels_for_hub")[hub_id] do
      do_on_hubs_event(channel_ids, hub_id, event, context, payload)
    end
  end

  def do_on_hubs_event(
        channel_ids,
        _hub_id,
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
        _hub_id,
        event,
        %{:profile => %{"displayName" => username}},
        _payload
      )
      when event in [:join, :part] do
    Enum.each(channel_ids, &broadcast_user_event_to_discord(&1, username, event))
  end

  defp content_for_payload(%{"type" => "chat"} = payload, _username),
    do: [content: payload["body"]]

  defp content_for_payload(%{"type" => "spawn"} = _payload, username) do
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
      worker(Cachex, [:discord_bot_state, []])
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end
end
