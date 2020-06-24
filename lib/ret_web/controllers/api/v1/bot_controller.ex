defmodule RetWeb.Api.V1.BotController do
	use RetWeb, :controller

	@slack_api_base "https://slack.com"
	@help_text "Command reference:\n\n" <>
	"🦆 `/hubs` - Shows general information about the Hubs integration with the current Slack channel.\n" <>
	"🦆 `/hubs help` - Shows this text you're reading right now.\n" <>
	"🦆 `/hubs create` - Creates a default Hubs room and puts its URL into the channel topic. " <>
	"Rooms created with `/hubs create` will inherit moderation permissions from this Slack channel and only allow Slack users in this channel to join the room.\n" <>
	"🦆 `/hubs create [environment URL] [name]` - Creates a new room with the given environment and name, and puts its URL into the channel topic. " <>
	"Valid environment URLs include GLTFs, GLBs, and Spoke scene pages.\n" <>
	"🦆 `/hubs remove` - Removes the room URL from the topic and stops bridging this Slack channel with Hubs."

	def index(conn, params) do
		IO.puts("hit index")
		# parsed_body = Poison.Parser.parse!(body)
		conn
		|> send_resp(200, "Hello view") # ack
	end

	def create(conn, params) do
		%{"command" => command, "channel_id" => channel_id, "text" => text} = params

		args = String.split(text, " ")
		IO.puts(Enum.at(args, 0))

		IO.inspect(args)

		IO.puts(command)
		IO.puts(command === "/hubs")
		send_message_to_channel(channel_id, "Hello robin")
		IO.inspect(params)

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
		|> send_resp(200, "") # ack

	end

	defp handle_command("help" = _command, _args) {
		send_message_to_channel()
	}

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
