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

  defmodule Commands do
    use Alchemy.Cogs
    require Alchemy.Embed, as: Embed

    Cogs.def duck do
      Cogs.say("Quack :duck:")
    end

    # Cogs.def bound do
    #   {:ok, mappings} = HubsBot.BotState.get_channel_mapping()

    #   fields =
    #     mappings
    #     |> Enum.map(fn {hub_id, channels} ->
    #       %Alchemy.Embed.Field{
    #         name: hub_id,
    #         value: Enum.map_join(channels, ",", &("#" <> &1.name))
    #       }
    #     end)

    #   embed = %Embed{
    #     title: "Bound channels",
    #     fields: fields
    #   }

    #   Embed.send(embed)
    # end
  end

  defmodule Events do
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
      unless msg.author.bot do
        hub_ids = HubsBot.BotState.get_hubs_for_channel(msg.channel_id)

        if hub_ids do
          hub_ids |> Enum.each(&broadcast_to_hubs(&1, msg))
        end
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

    def update_bound_channels do
      bound_channels =
        for guild <- elem(Alchemy.Client.get_current_guilds(), 1),
            channel <- elem(Alchemy.Client.get_channels(guild.id), 1),
            topic = channel.topic,
            channel_url = URI.parse(topic),
            channel_url.host === "hubs.local" do
          "/" <> hub_id = channel_url.path
          {hub_id, channel.id}
        end

      channels_by_hub =
        bound_channels |> Enum.group_by(&elem(&1, 0), &elem(&1, 1)) |> IO.inspect()

      hubs_by_channel =
        bound_channels |> Enum.group_by(&elem(&1, 1), &elem(&1, 0)) |> IO.inspect()

      HubsBot.BotState.set_channel_mappings(channels_by_hub, hubs_by_channel)
    end
  end

  def on_hubs_message(hub_id, username, content) do
    channel_ids = HubsBot.BotState.get_channels_for_hub(hub_id)

    if channel_ids do
      Enum.each(channel_ids, &broadcast_message_to_discord(&1, username, content))
    end
  end

  def on_hubs_user_event(hub_id, username, event) do
    channel_ids = HubsBot.BotState.get_channels_for_hub(hub_id)

    if channel_ids do
      Enum.each(channel_ids, &broadcast_user_event_to_discord(&1, username, event))
    end
  end

  def broadcast_message_to_discord(channel_id, username, content) do
    IO.puts("sending message for #{username} to #{channel_id}: #{content}")
    {:ok, [hook | _]} = Alchemy.Webhook.in_channel(channel_id)

    Alchemy.Webhook.send(
      hook,
      {:content, content},
      username: username,
      avatar_url: "https://blog.mozvr.com/content/images/2018/04/image--1-.png"
    )
  end

  def broadcast_user_event_to_discord(channel_id, username, event) do
    IO.puts("sending join message for #{username} to #{channel_id}")

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

  def start_link(options \\ []) do
    pid = Supervisor.start_link(__MODULE__, options)
    use Commands
    use Events
    pid
  end

  def init(token, options \\ []) do
    children = [
      supervisor(Alchemy.Client, [module_config(:token), options]),
      BotState
    ]
    IO.puts(module_config(:token))

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end
end
