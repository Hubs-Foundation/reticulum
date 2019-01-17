defmodule DiscordSupervisor do
  use Supervisor
  alias Alchemy.Client
  alias Alchemy.Embed
  require Logger

  defmodule DiscordBot do
    use GenServer

    defmodule HubsCommands do
      use Alchemy.Cogs
      require Alchemy.Embed, as: Embed

      Cogs.def duck do
        Cogs.say("Quack :duck:")
      end

      Cogs.def bound do
        case Cachex.get!(:discord_bot_state, :hubs_for_channel)[message.channel_id] do
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

      def on_channel_update(_channel) do
        update_bound_channels()
      end

      def on_ready(_shard, _total_shards) do
        update_bound_channels()
      end

      def on_message(msg) do
        if hub_ids = !msg.author.bot && Cachex.get!(:discord_bot_state, :hubs_for_channel)[msg.channel_id] do
          Logger.debug "Outgoing message from Discord to Hubs: #{msg.content}"
          hub_ids |> Enum.each(&broadcast_to_hubs(&1, msg))
        end
      end

      def broadcast_to_hubs(hub_id, msg) do
        RetWeb.Endpoint.broadcast!("hub:#{hub_id}", "message", %{
              type: "chat",
              body: msg.content,
              from: "#{msg.author.username}##{msg.author.discriminator}"
                                   })
      end

      def update_bound_channels do
        hostnames = Application.get_env(:ret, Elixir.DiscordBot)[:hostnames] |> String.split
        host_clauses = hostnames |> Enum.map(&("#{&1}(?:\\:\\d+)?")) |> Enum.join("|")
        {:ok, hub_url_regex} = Regex.compile("https?://(?:#{host_clauses})/(\\w+)/?\\S*")

        bound_channels =
        for guild <- elem(Alchemy.Client.get_current_guilds(), 1),
          channel <- elem(Alchemy.Client.get_channels(guild.id), 1),
          topic = channel.topic,
          matches = Regex.scan(hub_url_regex, topic),
          [_, hub_id] <- matches do
          {hub_id, channel.id}
        end

        channels_for_hub = bound_channels |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
        hubs_for_channel = bound_channels |> Enum.group_by(&elem(&1, 1), &elem(&1, 0))

        Logger.debug "Bound Discord channels per hub: #{inspect(channels_for_hub)}"
        Cachex.transaction!(:discord_bot_state, [:hubs_for_channel, :channels_for_hub], fn(cache) ->
          Cachex.put!(cache, :hubs_for_channel, hubs_for_channel)
          Cachex.put!(cache, :channels_for_hub, channels_for_hub)
        end)
      end
    end

    def init(_args) do
      {:ok, nil}
    end

    def start_link() do
      # conventionally, we will only have one of these running at once on the cluster,
      # since the supervisor that starts it is one-per-cluster (enforced by DiscordBotManager)
      result = GenServer.start_link(__MODULE__, [], [name: {:global, DiscordBot}])
      with {:ok, _} <- result do
        use HubsCommands
        use HubsEvents
      end
      result
    end

    def handle_cast(%{hub_sid: hub_sid} = data, state) do
      if channel_ids = Cachex.get!(:discord_bot_state, :channels_for_hub)[hub_sid] do
        %{event: event, context: %{:profile => %{"displayName" => username}}} = data
        case event do
          e when e == :join or e == :part ->
            Enum.each(channel_ids, &broadcast_user_event_to_discord(&1, username, e))
          :message ->
            %{payload: payload} = data
            Enum.each(channel_ids, &broadcast_message_to_discord(&1, username, payload |> content_for_payload(username)))
        end
      end
      {:noreply, state}
    end

    defp content_for_payload(%{"type" => "chat"} = payload, _username), do: [content: payload["body"]]

    defp content_for_payload(%{"type" => "spawn"} = payload, username) do
      [
        embeds: [
          %Embed{}
          |> Embed.color(0xFF3464)
          |> Embed.author(
            name: "#{username} took a photo",
          icon_url: "https://blog.mozvr.com/content/images/2018/04/image--1-.png"
          )
          |> Embed.image(payload["body"]["src"])
        ]
      ]
    end

    def broadcast_message_to_discord(channel_id, username, options \\ []) do
      Logger.debug "Incoming message from Hubs to Discord: #{inspect(options)}"
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
      Logger.debug "Presence update from Hubs to Discord: #{inspect(event)}"
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

  end

  def start_link(args, options \\ []) do
    Supervisor.start_link(__MODULE__, args, options)
  end

  def init(options \\ []) do
    token = Application.get_env(:ret, Elixir.DiscordBot)[:token]
    children = [
      supervisor(Alchemy.Client, [token, options]),
      worker(DiscordBot, []),
      worker(Cachex, [:discord_bot_state, []])
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

end
