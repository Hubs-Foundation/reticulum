defmodule RetWeb.EntityStateView do
  use RetWeb, :view
  alias Ret.EntityState.CreateMessage
  alias RetWeb.EntityStateView

  def render("index.json", %{entity_states: entity_states}) do
    %{data: render_many(entity_states, EntityStateView, "entity_state.json")}
  end

  def render("show.json", %{entity_state: entity_state}) do
    %{data: [render_one(entity_state, EntityStateView, "entity_state.json")]}
  end

  def render("entity_state.json", %{entity_state: %CreateMessage{} = message}) do
    %{
      create_message: Poison.Parser.parse!(message.create_message, %{}),
      update_messages:
        Enum.map(
          message.entity_update_messages,
          fn u ->
            Poison.Parser.parse!(u.update_message, %{})
          end
        )
    }
  end
end
