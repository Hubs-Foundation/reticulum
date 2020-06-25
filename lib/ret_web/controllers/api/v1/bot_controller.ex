defmodule RetWeb.Api.V1.BotController do
	use RetWeb, :controller

	alias Ret.{Hub}

	@slack_api_base "https://slack.com"
	@help_prefix "Hi! I'm the Hubs bot. I connect Slack channels with rooms on Hubs (https://hubs.mozilla.com/). Type `/hubs help` for more information.";
	@help_text "Command reference:\n\n" <>
	"🦆 `/hubs` - Shows general information about the Hubs integration with the current Slack channel.\n" <>
	"🦆 `/hubs help` - Shows this text you're reading right now.\n" <>
	"🦆 `/hubs create` - Creates a default Hubs room and puts its URL into the channel topic. " <>
	"Rooms created with `/hubs create` will inherit moderation permissions from this Slack channel and only allow Slack users in this channel to join the room.\n" <>
	"🦆 `/hubs create [environment URL] [name]` - Creates a new room with the given environment and name, and puts its URL into the channel topic. " <>
	"Valid environment URLs include GLTFs, GLBs, and Spoke scene pages.\n" <>
	"🦆 `/hubs remove` - Removes the room URL from the topic and stops bridging this Slack channel with Hubs."


	# def index(conn, params) do
	# 	IO.puts("hit index")
	# 	# parsed_body = Poison.Parser.parse!(body)
	# 	conn
	# 	|> send_resp(200, "Hello view") # ack
	# end

	def create(conn, params) do
		conn
		|> send_resp(200, "") # ack

		%{"command" => command, "channel_id" => channel_id, "text" => text} = params

		args = String.split(text, " ")
		IO.puts(Enum.at(args, 0))

		IO.inspect(args)

		IO.puts(command)
		IO.puts(command === "/hubs")
		send_message_to_channel(channel_id, "Hello robin")
		IO.inspect(params)

		handle_command(List.first(args), channel_id, args)

		# "channel_id" => "C0133V80YFM",
		# "channel_name" => "i-be-a-room",
		# "command" => "/hubs",
		# "response_url" => "https://hooks.slack.com/commands/T0139U6GLR2/1225874938976/nfap6umE8qF2hrxm5xMk32Y6",
		# "team_domain" => "hellohubs",
		# "team_id" => "T0139U6GLR2",
		# "text" => "",
		# "token" => "MI3qloN2YXse16mAzZXSd00m",
		# "trigger_id" => "1200660223541.1111958564852.467ce1bc761cf16e21c55217161d04a7",
		# "user_id" => "U0133NXSVTL",
		# "user_name" => "rwilson"
		conn
	end

	defp handle_command("help" = _command, channel_id, _args) do
		send_message_to_channel(channel_id, @help_text)
	end

	defp handle_command("" = _command, channel_id, _args) do
		send_message_to_channel(channel_id, @help_prefix)
	end

	defp handle_command("create" = _command, channel_id, args) do
		%{"channel" => %{"topic" => topic}} = get_channel_info(channel_id)
		send_message_to_channel(channel_id, "Topic is :" <> topic)

		if (String.match(topic, get_hub_url_regex()))
			send_message_to_channel(channel_id, "A Hubs room is already bridged in the topic, so I am cowardly refusing to replace it.")
		else
			environmentURL = Enum.at(args, 1)
			channelName = Enum.at(args, 2)
		end

		# TODO ask if this is best way to handle


		# const channelInfo = await getChannelInfo(channelId);
		# const channelTopic = getChannelTopic(channelInfo);
		# const environmentURL = argumentList[0] ? argumentList[0] : process.env.DEFAULT_SCENE_URL;
		# const name = argumentList[1] ? argumentList[1] : channelName;
		# if (topicManager.matchHub(channelTopic)) {
		#   return sendMessageToChannel(
		# 	channelId,
		# 	"A Hubs room is already bridged in the topic, so I am cowardly refusing to replace it."
		#   );
		# }

		# await sendMessageToChannel(channelId, "Creating room...");

		# const { sceneId } = topicManager.matchScene(environmentURL) || {};
		# const { url: hubUrl, hub_id: hubId } = sceneId
		#   ? await reticulumClient.createHubFromScene(name, sceneId)
		#   : await reticulumClient.createHubFromUrl(name, environmentURL);
		# const updatedTopic = topicManager.addHub(channelTopic, hubUrl);
		# if (VERBOSE) console.log(`Updated topic is: "${updatedTopic}"`);
		# if ((await setChannelTopic(channelId, updatedTopic)) != null) {
		#   if (VERBOSE) console.log("Set channel topic, now binding Hub: " + hubId);
		#   return reticulumClient.bindHub(hubId, "slack", teamId, channelId);
		# }

	end

	defp handle_command("remove" = _command, channel_id, args) do
		%{"channel" => %{"topic" => topic}} = get_channel_info(channel_id)
		send_message_to_channel(channel_id, "Topic is :" <> topic)
		if (!String.match(topic, get_hub_url_regex()))
			send_message_to_channel(channel_id, "No Hubs room is bridged in the topic, so doing nothing :eyes:")
		else
			update_topic(channel_id, remove_hub_topic(topic))
		end
	end

	# catches requests that do not match the specified commands above
	defp handle_command(_command, channel_id, args) do
		send_message_to_channel(channel_id, "Type \"/hubs help\" if you need the list of available commands")
	end

	defp has_hubs_url(topic) do
		String.match(topic, get_hub_url_regex())
	end

	defp remove_hub_topic (topic) do
		new_topic = Regex.replace(get_hub_url_regex(), topic, "")
		# In Slack topic, hub url is surrounded by '<>' in slack ex: <https://etc>
		# A topic set in slack with <> will not match regex. It's coded with '&gt;&lt;'
		Regex.replace(~r/[<>]/, new_topic, "")
		Regex.replace(~r/(\s*\|\s*)+$/, new_topic, "")
	end

	defp add_hub_topic(topic, hub_url) do
		new_topic = if (topic === ""), do: hub_url, else: topic <> " | " <> hub_url
	end

	defp get_hub_url_regex() do
		# "https?://(#{module_config(:host)}(?:\\:\\d+)?)/\\S*"
		# https?://(hubs.local(?:\\:\\d+)?)/\\S*
		# |> ~r()
		{:ok ,  reg } = Regex.compile("https?://(#{module_config(:host)}(?:\\:\\d+)?)/\\S*")
		# print = String.match?("https://hubs.local:4000/zDN9k2t/i-be-a-room", reg)
		reg
	end

	# removeHub(topic)
	# 	return cleanSuffix(topic.replace(this.hubUrlRe, ""));
	#   }

	#   addHub(topic, hubUrl) {
	# 	return topic ? `${topic} | ${hubUrl}` : hubUrl;
	#   }

	defp update_topic(channel_id, new_topic) do
		("#{@slack_api_base}/api/conversations.setTopic" <>
		URI.encode_query(%{token: module_config(:bot_token), channel: channel_id, topic: new_topic}))
		|> Ret.HttpUtils.retry_post_until_success()
		|> Map.get(:body)
		|> Poison.decode!()
	end

	defp get_channel_info(channel_id) do
		("#{@slack_api_base}/api/conversations.info?" <>
		URI.encode_query(%{token: module_config(:bot_token), channel: channel_id}))
		|> Ret.HttpUtils.retry_get_until_success()
		|> Map.get(:body)
		|> Poison.decode!()

		# {
		# 	"ok": true,
		# 	"channel": {
		# 		"id": "C012AB3CD",
		# 		"name": "general",
		# 		"is_channel": true,
		# 		"is_group": false,
		# 		"is_im": false,
		# 		"created": 1449252889,
		# 		"creator": "W012A3BCD",
		# 		"is_archived": false,
		# 		"is_general": true,
		# 		"unlinked": 0,
		# 		"name_normalized": "general",
		# 		"is_read_only": false,
		# 		"is_shared": false,
		# 		"parent_conversation": null,
		# 		"is_ext_shared": false,
		# 		"is_org_shared": false,
		# 		"pending_shared": [],
		# 		"is_pending_ext_shared": false,
		# 		"is_member": true,
		# 		"is_private": false,
		# 		"is_mpim": false,
		# 		"last_read": "1502126650.228446",
		# 		"topic": {
		# 			"value": "For public discussion of generalities",
		# 			"creator": "W012A3BCD",
		# 			"last_set": 1449709364
		# 		},
		# 		"purpose": {
		# 			"value": "This part of the workspace is for fun. Make fun here.",
		# 			"creator": "W012A3BCD",
		# 			"last_set": 1449709364
		# 		},
		# 		"previous_names": [
		# 			"specifics",
		# 			"abstractions",
		# 			"etc"
		# 		],
		# 		"locale": "en-US"
		# 	}
		# }
	end

	defp send_message_to_channel(channel_id, message) do
		("#{@slack_api_base}/api/chat.postMessage?" <>
		   URI.encode_query(%{token: module_config(:bot_token), channel: channel_id, text: message}))
		|> Ret.HttpUtils.retry_get_until_success()
		|> Map.get(:body)
		|> Poison.decode!()
	end

	defp module_config(key) do
		Application.get_env(:ret, __MODULE__)[key]
	end
end
