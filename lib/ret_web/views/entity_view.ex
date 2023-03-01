defmodule RetWeb.EntityView do
  use RetWeb, :view

  alias Ret.Entity
  alias RetWeb.EntityView

  def render("index.json", %{entities: entities}) do
    %{data: render_many(entities, EntityView, "entity.json")}
  end

  def render("show.json", %{entity: entity}) do
    %{data: [render_one(entity, EntityView, "entity.json")]}
  end

  def render("entity.json", %{entity: %Entity{} = entity}) do
    %{
      create_message: Jason.decode!(entity.create_message, %{}),
      update_messages: Enum.map(entity.sub_entities, &Jason.decode!(&1.update_message, %{}))
    }
  end
end
