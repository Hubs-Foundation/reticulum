defmodule RetWeb.Middlewares.VerifyScopes do
  @moduledoc false

  alias Ret.ApiPermissions

  @behavior Absinthe.Middleware
  def call(resolution, _) do
    action = resolution.definition.schema_node.identifier

    case resolution.context do
      %{claims: claims} ->
        if verify_scope(action, claims) do
          resolution
        else
          Absinthe.Resolution.put_result(resolution, {:error, "unauthorized " <> Atom.to_string(action)})
        end

      _ ->
        Absinthe.Resolution.put_result(resolution, {:error, "unauthorized"})
    end
  end

  @action_to_permission %{
    create_room: :rooms_mutation_create_room,
    update_room: :rooms_mutation_update_room,
    my_rooms: :rooms_query_created_rooms,
    public_rooms: :rooms_query_public_rooms,
    favorite_rooms: :rooms_query_favorite_rooms
  }

  defp verify_scope(action, claims) do
    IO.inspect(action)
    IO.inspect(claims)
    IO.inspect(Map.get(claims, Atom.to_string(Map.get(@action_to_permission, action))))
  end
end
