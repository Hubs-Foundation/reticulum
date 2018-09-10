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
      |> notify_slack_handles(hub)
    end
  end

  defp notify_slack_handles(handles, hub) do
    with slack_url when is_binary(slack_url) <- module_config(:slack_webhook_url) do
      at_handles = handles |> Enum.map(fn h -> "@#{h}" end)

      payload =
        %{
          "icon_emoji" => ":quest:",
          "link_names" => "1",
          "text" =>
            "*Incoming support request*\nOn call: #{at_handles |> Enum.join(" ")}\n<#{RetWeb.Endpoint.url()}/#{
              hub.hub_sid
            }|Enter Now>"
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
