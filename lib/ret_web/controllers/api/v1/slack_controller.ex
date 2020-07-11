defmodule RetWeb.Api.V1.SlackController do
  use RetWeb, :controller
  alias Ret.{Hub, HubBinding}

  # Limit to 1 TPS
  plug(RetWeb.Plugs.RateLimit)

  @slack_api_base "https://slack.com"
  @help_prefix "Hi! I'm the Hubs bot. I connect Slack channels with rooms on Hubs (https://hubs.mozilla.com/). Type `/hubs help` for more information."
  @help_text "Command reference:\n\n" <>
               "🦆 `/hubs help` - Shows the help text you're reading right now.\n" <>
               "🦆 `/hubs create` - Creates a default Hubs room and puts its URL into the channel topic. " <>
               "Rooms created with `/hubs create` will inherit moderation permissions from this Slack channel and only allow Slack users in this channel to join the room.\n" <>
               "🦆 `/hubs create [name]` - Creates a new room with the name and puts its URL into the channel topic.\n" <>
               "🦆 `/hubs remove` - Removes the room URL from the topic."

  def create(conn, params) do
    %{:query_params => %{"token" => reticulum_token}} = conn

    if is_nil(module_config(:token)) || reticulum_token !== module_config(:token) do
      conn
      |> send_resp(401, "Missing reticulum \"token\" in query params.")
    else
      %{
        "channel_id" => channel_id,
        # "text" = "help/create/etc. arg1 arg2 arg3"
        "text" => text,
        "team_id" => team_id
      } = params

      # Parse arguments
      args = String.split(text, " ")
      command = List.first(args)
      optional_args = List.delete_at(args, 0)

      handle_command(command, channel_id, optional_args, team_id)

      conn
      |> send_resp(200, "")
    end
  end

  defp handle_command("help", channel_id, _args, _team_id) do
    send_message_to_channel(channel_id, @help_text)
  end

  defp handle_command("create", channel_id, args, team_id) do
    %{
      "channel" => %{
        "name" => channel_name,
        "topic" => %{"value" => topic}
      }
    } = get_channel_info(channel_id)

    name = if is_nil(Enum.at(args, 0)), do: channel_name, else: Enum.join(args, " ")

    cond do
      has_hubs_url(topic) ->
        send_message_to_channel(
          channel_id,
          "A Hubs room is already bridged in the topic, so I am cowardly refusing to replace it."
        )

      String.length(name) > 64 ->
        send_message_to_channel(
          channel_id,
          "Room name is too long (over 64 characters). Please shorten room name."
        )

      true ->
        {:ok, %{hub_sid: hub_sid} = new_hub} = Hub.create_new_room(%{"name" => name}, true)

        HubBinding.bind_hub(%{
          "hub_id" => hub_sid,
          "type" => "slack",
          "community_id" => team_id,
          "channel_id" => channel_id
        })

        update_topic(channel_id, add_hub_topic(topic, Hub.url_for(new_hub)))
    end
  end

  defp handle_command("remove", channel_id, _args, _team_id) do
    %{"channel" => %{"topic" => %{"value" => topic}}} = get_channel_info(channel_id)

    if !has_hubs_url(topic) do
      send_message_to_channel(channel_id, "No Hubs room is bridged in the topic, so doing nothing :eyes:")
    else
      update_topic(channel_id, remove_hub_topic(topic))
    end
  end

  defp handle_command("", channel_id, _args, _team_id) do
    send_message_to_channel(channel_id, @help_prefix)
  end

  # catches requests that do not match the specified commands above
  defp handle_command(_command, channel_id, _args, _team_id) do
    send_message_to_channel(channel_id, "Type \"/hubs help\" if you need the list of available commands")
  end

  defp has_hubs_url(topic) do
    String.match?(topic, get_hub_url_regex())
  end

  defp remove_hub_topic(topic) do
    # In Slack topic, hub url is surrounded by '<>' in slack ex: <https://etc>
    # A topic set in slack with <> will not match regex. It's coded with '&gt;&lt;'
    new_topic = Regex.replace(~r/[<>]/, topic, "")
    new_topic2 = Regex.replace(get_hub_url_regex(), new_topic, "")
    Regex.replace(~r/(\s*\|\s*)+$/, new_topic2, "")
  end

  defp add_hub_topic(topic, hub_url) do
    if topic === "", do: hub_url, else: topic <> " | " <> hub_url
  end

  defp get_hub_url_regex() do
    {:ok, reg} = Regex.compile("https?://(#{RetWeb.Endpoint.host()}(?:\\:\\d+)?)/\\S*")
    reg
  end

  defp update_topic(channel_id, new_topic) do
    ("#{@slack_api_base}/api/conversations.setTopic?" <>
       URI.encode_query(%{token: get_bot_token(), channel: channel_id, topic: new_topic}))
    |> Ret.HttpUtils.retry_get_until_success()
  end

  defp send_message_to_channel(channel_id, message) do
    ("#{@slack_api_base}/api/chat.postMessage?" <>
       URI.encode_query(%{token: get_bot_token(), channel: channel_id, text: message}))
    |> Ret.HttpUtils.retry_get_until_success()
  end

  defp get_channel_info(channel_id) do
    ("#{@slack_api_base}/api/conversations.info?" <> URI.encode_query(%{token: get_bot_token(), channel: channel_id}))
    |> Ret.HttpUtils.retry_get_until_success()
    |> Map.get(:body)
    |> Poison.decode!()
  end

  defp get_bot_token() do
    Application.get_env(:ret, Ret.SlackClient)[:bot_token]
  end

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end
end
