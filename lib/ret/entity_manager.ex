defmodule Ret.EntityManager do
  alias Ecto.Multi
  alias Ret.{Entity, SubEntity, Repo}
  import Ecto.Query

  def create_entity(hub, %{updates: updates} = entity_params) do
    Multi.new()
    |> Multi.insert(:entity, Entity.changeset(%Entity{}, hub, entity_params))
    |> Multi.insert_all(
      :sub_entities,
      SubEntity,
      fn %{entity: entity} ->
        Enum.map(updates, &SubEntity.for_bulk_insert(hub, entity, &1))
      end
    )
  end

  def insert_or_update_sub_entity(hub, %{root_nid: root_nid, nid: nid} = params) do
    Multi.new()
    |> Multi.run(:entity, fn _repo, _changes ->
      case Repo.one(from Entity, where: [nid: ^root_nid], preload: [:sub_entities]) do
        nil -> {:error, :entity_state_does_not_exist}
        entity -> {:ok, entity}
      end
    end)
    |> Multi.run(:existing_sub_entity, fn _repo, _changes ->
      {:ok, Repo.one(from SubEntity, where: [nid: ^nid], preload: [:hub, :entity])}
    end)
    |> Multi.insert_or_update(:sub_entity, fn %{
                                                entity: entity,
                                                existing_sub_entity: existing_sub_entity
                                              } ->
      SubEntity.changeset(existing_sub_entity || %SubEntity{}, hub, entity, params)
    end)
  end
end
