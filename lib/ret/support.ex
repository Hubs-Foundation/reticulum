defmodule Ret.Support do
  alias Ret.{Repo, Support, SupportSubscription}

  import Ecto.Query

  def available? do
    SupportSubscription |> Repo.all() |> Enum.empty?() |> Kernel.not()
  end

  def request_support_for_hub(hub) do
    if Support.available?() do
      SupportSubscription
      |> where(channel: "slack")
      |> Repo.all()
      |> Enum.map(&Map.get(&1, :identifier))
      |> notify_slack_handles_of_hub_support(hub)
    end
  end

  def send_notification_of_new_scene(scene) do
    scene_url = scene |> Ret.Scene.to_url()

    notify_slack(
      ":sunrise_over_mountains:",
      "New scene: #{scene_url}"
    )
  end

  defp notify_slack_handles_of_hub_support(handles, hub) do
    at_handles = handles |> Enum.map(fn h -> "@#{h}" end)

    message =
      "*Incoming support request*\nOn call: #{at_handles |> Enum.join(" ")}\n<#{
        RetWeb.Endpoint.url()
      }/#{hub.hub_sid}|Enter Now>"

    notify_slack(":quest", message)
  end

  defp notify_slack(emoji, message) do
    with slack_url when is_binary(slack_url) and slack_url != "" <-
           module_config(:slack_webhook_url) do
      payload =
        %{
          "icon_emoji" => emoji,
          "link_names" => "1",
          "unfurl_links" => true,
          "text" => message
        }
        |> Poison.encode!()

      {:ok, _resp} = HTTPoison.post(slack_url, payload, [{"Content-Type", "application/json"}])
    end

    {:ok}
  end

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end
end
