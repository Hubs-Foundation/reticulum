defmodule Ret.EntityState do
  import Ecto.Query, warn: false
  alias Ret.{Hub, Repo}

  alias Ret.EntityState.{CreateMessage, UpdateMessage}

  def list_entity_states(hub_id) do
    Repo.all(
      from create_message in CreateMessage,
        where: create_message.hub_id == ^hub_id,
        preload: [:entity_update_messages]
    )
  end

  def create_entity_state!(
        %Hub{hub_id: hub_id} = hub,
        %{nid: nid, create_message: create_message, updates: updates}
      ) do
    Repo.transaction(fn ->
      %CreateMessage{}
      |> CreateMessage.changeset(hub, %{
        nid: nid,
        create_message: Poison.encode!(create_message)
      })
      |> Repo.insert!()

      for update <- updates do
        # TODO How / where are we supposed to handle string <-> atom conversion?
        update_entity_state!(hub, %{
          root_nid: nid,
          nid: update["nid"],
          update_message: update["update_message"]
        })
      end

      Repo.one!(
        from create_message in CreateMessage,
          where: create_message.hub_id == ^hub_id,
          where: create_message.nid == ^nid,
          preload: [:entity_update_messages]
      )
    end)
  end

  def update_entity_state!(
        %Hub{hub_id: hub_id} = hub,
        %{root_nid: root_nid, nid: nid, update_message: update_message}
      ) do
    Repo.transaction(fn ->
      create_message =
        Repo.one!(
          from create_message in CreateMessage,
            where: create_message.hub_id == ^hub_id,
            where: create_message.nid == ^root_nid
        )

      entity_update_message =
        Repo.one(
          from um in UpdateMessage,
            where: um.entity_create_message_id == ^create_message.entity_create_message_id,
            where: um.nid == ^nid,
            preload: [:hub, :entity_create_message]
        )

      (entity_update_message || %UpdateMessage{})
      |> UpdateMessage.changeset(hub, create_message, %{
        nid: nid,
        update_message: Poison.encode!(update_message)
      })
      |> Repo.insert_or_update!()
    end)
  end

  def delete_entity_state!(hub_id, nid) do
    Repo.transaction(fn ->
      create_message =
        Repo.one!(
          from create_message in CreateMessage,
            where: create_message.hub_id == ^hub_id,
            where: create_message.nid == ^nid
        )

      Repo.delete_all(
        from update_message in UpdateMessage,
          where:
            update_message.entity_create_message_id == ^create_message.entity_create_message_id
      )

      Repo.delete!(create_message)
    end)
  end
end
