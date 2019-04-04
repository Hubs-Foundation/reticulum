defmodule Ret.HubBinding do
  use Ecto.Schema

  import Ecto.Changeset

  alias Ret.{Hub, HubBinding, Repo}

  @schema_prefix "ret0"
  @primary_key {:hub_binding_id, :id, autogenerate: true}

  schema "hub_bindings" do
    field(:type, HubBinding.Type)
    field(:community_id, :string)
    field(:channel_id, :string)
    belongs_to(:hub, Hub, references: :hub_id)

    timestamps()
  end

  def changeset(%HubBinding{} = hub_binding, params) do
    %Hub{hub_id: hub_id} = Hub |> Repo.get_by(hub_sid: params["hub_id"])

    hub_binding
    |> cast(params, [:type, :community_id, :channel_id])
    |> put_change(:hub_id, hub_id)
  end

  def can_manage_channel?(%Ret.Account{} = account, %Ret.HubBinding{type: :discord} = hub_binding) do
    account |> matching_oauth_provider(hub_binding) |> Ret.DiscordClient.has_permission?(hub_binding, :manage_channels)
  end

  def can_moderate_users?(%Ret.Account{} = account, %Ret.HubBinding{type: :discord} = hub_binding) do
    account |> matching_oauth_provider(hub_binding) |> Ret.DiscordClient.has_permission?(hub_binding, :kick_members)
  end

  def member_of_channel?(%Ret.Account{} = account, %Ret.HubBinding{} = hub_binding) do
    account |> matching_oauth_provider(hub_binding) |> member_of_channel?(hub_binding)
  end

  def member_of_channel?(
        %Ret.OAuthProvider{source: :discord} = oauth_provider,
        %Ret.HubBinding{type: :discord} = hub_binding
      ) do
    oauth_provider |> Ret.DiscordClient.has_permission?(hub_binding, :view_channel)
  end

  def member_of_channel?(_, _), do: false

  defp matching_oauth_provider(account, hub_binding) do
    account.oauth_providers |> Enum.find(&(&1.source == hub_binding.type))
  end
end
