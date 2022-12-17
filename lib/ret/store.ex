defmodule Ret.Store do
  import Ecto.Query, warn: false
  alias Ret.{Hub, Repo}

  alias Ret.Store.EntityState

  def list_entity_states(hub_id) do
    Repo.all(
      from entity_state in EntityState,
        where: entity_state.hub_id == ^hub_id
    )
  end

  def save_entity_state!(
        %Hub{hub_id: hub_id} = hub,
        %{nid: nid} = attrs
      ) do
    entity_state =
      Repo.one(
        from entity_state in EntityState,
          where: entity_state.hub_id == ^hub_id,
          where: entity_state.nid == ^nid,
          preload: [:hub]
      )

    (entity_state || %EntityState{})
    |> EntityState.changeset(hub, attrs)
    |> Repo.insert_or_update!()
  end

  def delete_entity_state!(hub_id, nid) do
    entity_state =
      Repo.one(
        from entity_state in EntityState,
          where: entity_state.hub_id == ^hub_id,
          where: entity_state.nid == ^nid,
          preload: [:hub]
      )

    if entity_state do
      Repo.delete!(entity_state)
    else
      nil
    end
  end

  def delete_entity_states_for_root_nid!(hub_id, root_nid) do
    Repo.delete_all(
      from entity_state in EntityState,
        where: entity_state.hub_id == ^hub_id,
        where: entity_state.root_nid == ^root_nid
    )
  end
end
