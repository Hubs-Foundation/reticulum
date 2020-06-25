defmodule RetWeb.Api.V1.BotController do
  use RetWeb, :controller

  alias RetWeb.Api.V1.{HubController}
  alias Ret.{Hub}

  @slack_api_base "https://slack.com"
  @help_prefix "Hi! I'm the Hubs bot. I connect Slack channels with rooms on Hubs (https://hubs.mozilla.com/). Type `/hubs help` for more information."
  @help_text "Command reference:\n\n" <>
               "🦆 `/hubs` - Shows general information about the Hubs integration with the current Slack channel.\n" <>
               "🦆 `/hubs help` - Shows this text you're reading right now.\n" <>
               "🦆 `/hubs create` - Creates a default Hubs room and puts its URL into the channel topic. " <>
               "Rooms created with `/hubs create` will inherit moderation permissions from this Slack channel and only allow Slack users in this channel to join the room.\n" <>
               "🦆 `/hubs create [environment URL] [name]` - Creates a new room with the given environment and name, and puts its URL into the channel topic. " <>
               "Valid environment URLs include GLTFs, GLBs, and Spoke scene pages.\n" <>
               "🦆 `/hubs remove` - Removes the room URL from the topic and stops bridging this Slack channel with Hubs."

  def create(conn, params) do
    %{
      # "/hubs"
      "command" => command,
      "channel_id" => channel_id,
      # "help/create/etc. arg1 arg2 arg3"
      "text" => text,
      "team_id" => team_id
    } = params

    # TODO check if there's any double spaces
    args = String.split(text, " ")
    handle_command(List.first(args), channel_id, args, team_id)

    conn
    |> send_resp(200, "")
  end

  defp handle_command("help" = _command, channel_id, _args, _team_id) do
    send_message_to_channel(channel_id, @help_text)
  end

  defp handle_command("" = _command, channel_id, _args, _team_id) do
    send_message_to_channel(channel_id, @help_prefix)
  end

  defp handle_command("create" = _command, channel_id, args, team_id) do
    %{
      "channel" => %{
        "name" => channel_name,
        "topic" => %{"value" => topic}
      }
    } = get_channel_info(channel_id)

    if has_hubs_url(topic) do
      send_message_to_channel(
        channel_id,
        "A Hubs room is already bridged in the topic, so I am cowardly refusing to replace it."
      )
    else
      # environmentURL = if (Enum.at(args, 1)) === nil, do "", else Enum.at(args, 1)
      # name = if (Enum.at(args, 2)) === nil, do channelName, else Enum.at(args, 2)
      params = %{
        name: channel_name
        # default_environment_gltf_bundle_url: sceneurl,
        # scene_id: sceneid
      }

      {:ok, %{hub_sid: hub_sid} = new_hub} = HubController.create_new_room(params)
      update_topic(channel_id, add_hub_topic(topic, Hub.url_for(new_hub)))

      RetWeb.Api.V1.HubBindingController.bind_hub(%{
        "hub_id" => hub_sid,
        "type" => "slack",
        "community_id" => team_id,
        "channel_id" => channel_id
      })
    end
  end

  defp handle_command("remove" = _command, channel_id, _args, _team_id) do
    %{"channel" => %{"topic" => %{"value" => topic}}} = get_channel_info(channel_id)

    send_message_to_channel(channel_id, "Topic is :" <> topic)

    if !has_hubs_url(topic) do
      send_message_to_channel(channel_id, "No Hubs room is bridged in the topic, so doing nothing :eyes:")
    else
      update_topic(channel_id, remove_hub_topic(topic))
    end
  end

  # catches requests that do not match the specified commands above
  defp handle_command(_command, channel_id, _args, _team_id) do
    send_message_to_channel(channel_id, "Type \"/hubs help\" if you need the list of available commands")
  end

  defp has_hubs_url(topic) do
    String.match?(topic, get_hub_url_regex())
  end

  defp remove_hub_topic(topic) do
    new_topic = Regex.replace(~r/[<>]/, topic, "")
    new_topic2 = Regex.replace(get_hub_url_regex(), new_topic, "")
    # In Slack topic, hub url is surrounded by '<>' in slack ex: <https://etc>
    # A topic set in slack with <> will not match regex. It's coded with '&gt;&lt;'
    Regex.replace(~r/(\s*\|\s*)+$/, new_topic2, "")
  end

  defp add_hub_topic(topic, hub_url) do
    if topic === "", do: hub_url, else: topic <> " | " <> hub_url
  end

  defp get_hub_url_regex() do
    {:ok, reg} = Regex.compile("https?://(#{module_config(:host)}(?:\\:\\d+)?)/\\S*")
    reg
  end

  defp update_topic(channel_id, new_topic) do
    ("#{@slack_api_base}/api/conversations.setTopic?" <>
       URI.encode_query(%{token: module_config(:bot_token), channel: channel_id, topic: new_topic}))
    |> Ret.HttpUtils.retry_get_until_success()
    |> Map.get(:body)
    |> Poison.decode!()
  end

  defp send_message_to_channel(channel_id, message) do
    ("#{@slack_api_base}/api/chat.postMessage?" <>
       URI.encode_query(%{token: module_config(:bot_token), channel: channel_id, text: message}))
    |> Ret.HttpUtils.retry_get_until_success()
    |> Map.get(:body)
    |> Poison.decode!()
  end

  defp get_channel_info(channel_id) do
    ("#{@slack_api_base}/api/conversations.info?" <>
       URI.encode_query(%{token: module_config(:bot_token), channel: channel_id}))
    |> Ret.HttpUtils.retry_get_until_success()
    |> Map.get(:body)
    |> Poison.decode!()
  end

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end
end
