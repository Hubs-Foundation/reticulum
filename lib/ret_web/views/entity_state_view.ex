defmodule RetWeb.EntityStateView do
  use RetWeb, :view
  alias RetWeb.EntityStateView

  def render("index.json", %{entity_states: entity_states}) do
    %{data: render_many(entity_states, EntityStateView, "entity_state.json")}
  end

  def render("show.json", %{entity_state: entity_state}) do
    %{data: render_one(entity_state, EntityStateView, "entity_state.json")}
  end

  def render("entity_state.json", %{entity_state: entity_state}) do
    %{
      root_nid: entity_state.root_nid,
      nid: entity_state.nid,
      message: Poison.Parser.parse!(entity_state.message, %{})
      # TODO Should hub_id be included here?
    }
  end
end
