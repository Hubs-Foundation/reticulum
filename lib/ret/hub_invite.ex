defmodule Ret.HubInvite do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ret.{Hub, HubInvite, Repo}

  @schema_prefix "ret0"
  @primary_key {:hub_invite_id, :id, autogenerate: true}

  schema "hub_invites" do
    field :hub_invite_sid, :string
    field :state, HubInvite.State

    belongs_to :hub, Hub, references: :hub_id

    timestamps()
  end

  def find_or_create_invite_for_hub(%Hub{} = hub) do
    hub_invite = HubInvite |> Repo.get_by(hub_id: hub.hub_id, state: :active)

    if hub_invite == nil do
      hub_invite_sid = Ret.Sids.generate_sid()

      change(%HubInvite{hub_id: hub.hub_id, hub_invite_sid: hub_invite_sid})
      |> unique_constraint(:hub_invite_sid)
      |> Repo.insert!()
    else
      hub_invite
    end
  end

  def revoke_invite(%Hub{} = hub, hub_invite_sid) when is_binary(hub_invite_sid) do
    hub_invite = HubInvite |> Repo.get_by(hub_id: hub.hub_id, hub_invite_sid: hub_invite_sid)
    change(hub_invite, state: :revoked) |> Repo.update!()
  end

  def active?(_hub, nil = _hub_invite_sid), do: false

  def active?(hub, hub_invite_sid) do
    case Ret.HubInvite |> Ret.Repo.get_by(hub_id: hub.hub_id, hub_invite_sid: hub_invite_sid) do
      nil -> false
      %Ret.HubInvite{state: :revoked} -> false
      %Ret.HubInvite{state: :active} -> true
    end
  end
end
