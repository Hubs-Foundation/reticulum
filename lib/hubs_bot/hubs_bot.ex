defmodule HubsBot do
  use Supervisor
  alias Alchemy.Client

  defmodule BotState do
    use GenServer

    def start_link(_opts) do
      GenServer.start_link(__MODULE__, :ok, name: BotState)
    end

    def set_channel_mapping!(mappings) do
      GenServer.cast(BotState, {:set_channel_mapping, mappings})
    end

    def get_channel_mapping() do
      GenServer.call(BotState, {:get_channel_mapping})
    end

    def init(:ok) do
      {:ok, %{}}
    end

    def handle_call({:get_channel_mapping}, _from, state) do
      {:reply, Map.fetch(state, :channel_mapping), state}
    end

    def handle_cast({:set_channel_mapping, mappings}, state) do
      {:noreply, Map.put(state, :channel_mapping, mappings)}
    end
  end

  defmodule Commands do
    use Alchemy.Cogs
    require Alchemy.Embed, as: Embed

    Cogs.def ping do
      Cogs.say("pong!")
    end

    Cogs.def chan do
      Cogs.say("Channel id #{message.channel_id}")
    end

    Cogs.def bound do
      {:ok, mappings} = HubsBot.BotState.get_channel_mapping()

      fields =
        mappings
        |> Enum.map(fn {hub_id, channels} ->
          %Alchemy.Embed.Field{
            name: hub_id,
            value: Enum.map_join(channels, ",", &("#" <> &1.name))
          }
        end)

      embed = %Embed{
        title: "Bound channels",
        fields: fields
      }

      Embed.send(embed)
    end

    Cogs.set_parser(:tohubs, &List.wrap/1)

    Cogs.def tohubs(msg) do
      IO.puts("Sending to hubs #{msg}")
      RetWeb.Endpoint.broadcast!("hub:Xb51YRn", "message", %{type: "chat", body: msg})
    end

    Cogs.def fakeit do
      require Alchemy.Webhook, as: Webhook
      {:ok, hook} = Webhook.create(message.channel_id, "test-hook")

      Webhook.send(hook, {:content, "hello world"},
        username: "AHubsUser",
        avatar_url: "https://blog.mozvr.com/content/images/2018/04/image--1-.png"
      )
      |> IO.inspect()
    end

    Cogs.def embed do
      require Alchemy.Embed, as: Embed

      embed =
        %Embed{}
        |> Embed.title("The BEST embed")
        |> Embed.description("the best description")
        |> Embed.image("http://i.imgur.com/4AiXzf8.jpg")

      IO.inspect(message)
      IO.inspect(embed)

      Embed.send(embed)
    end
  end

  defmodule Events do
    use Alchemy.Events

    Events.on_channel_update(:channel_updated)
    Events.on_ready(:on_ready)

    def channel_updated(channel) do
      IO.inspect("#{channel.name} was updated, topic: #{channel.topic}")
      update_bound_channels()
    end

    def on_ready(_shard, _total_shards) do
      update_bound_channels()
    end

    ###

    def hub_id_for_channel(channel) do
      "/" <> hub_id = URI.parse(channel.topic).path
      hub_id
    end

    def update_bound_channels do
      with {:ok, guilds} <- Alchemy.Client.get_current_guilds(),
           [ok: channels] <-
             guilds |> Enum.map(& &1.id) |> Enum.map(&Alchemy.Client.get_channels/1) do
        channels
        |> Enum.filter(&(&1.topic && URI.parse(&1.topic).host === "hubs.local"))
        |> Enum.group_by(&hub_id_for_channel/1)
        |> HubsBot.BotState.set_channel_mapping!()
      end
    end
  end

  def broadcast_chat_message!(hub_id, username, content) do
    with {:ok, mappings} <- HubsBot.BotState.get_channel_mapping(),
         channels <- Map.get(mappings, hub_id) do
      Enum.each(channels, fn channel ->
        IO.puts("sending message for #{username} to ##{channel.name}: #{content}")
        {:ok, [hook | _]} = Alchemy.Webhook.in_channel(channel.id)

        Alchemy.Webhook.send(
          hook,
          {:content, content},
          username: username,
          avatar_url: "https://blog.mozvr.com/content/images/2018/04/image--1-.png"
        )
      end)
    end
  end

  def start_link(token, options \\ []) do
    IO.puts("HubsBot start_link #{token}")
    run = Supervisor.start_link(__MODULE__, token, options)
    use Commands
    use Events
    run
  end

  def init(token, options \\ []) do
    IO.puts("HubsBot INIT")

    children = [
      supervisor(Alchemy.Client, [token, options]),
      BotState
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
