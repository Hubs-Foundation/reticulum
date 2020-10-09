defmodule RetWeb.Middleware.VerifyScopes do
  @moduledoc false

  import RetWeb.Middleware.PutErrorResult, only: [put_error_result: 3]

  @action_to_permission %{
    create_room: :rooms_mutation_create_room,
    update_room: :rooms_mutation_update_room,
    my_rooms: :rooms_query_created_rooms,
    public_rooms: :rooms_query_public_rooms,
    favorite_rooms: :rooms_query_favorite_rooms
  }

  @behaviour Absinthe.Middleware
  def call(%{state: :resolved} = resolution, _) do
    resolution
  end

  def call(resolution, _) do
    action = resolution.definition.schema_node.identifier

    case resolution.context do
      %{claims: claims} ->
        if verify_scope(action, claims) do
          resolution
        else
          missing_permission = Atom.to_string(Map.get(@action_to_permission, action))
          put_error_result(resolution, :unauthorized_scopes, "Token does not have permission: #{missing_permission}.")
        end

      _ ->
        put_error_result(resolution, :unauthorized, "Token is missing permissions.")
    end
  end

  defp verify_scope(action, claims) do
    Map.get(claims, Atom.to_string(Map.get(@action_to_permission, action)))
  end
end

defmodule RetWeb.Middleware.LogMiddleware do
  @moduledoc false

  @behaviour Absinthe.Middleware

  def call(resolution, _) do
    resolution
  end
end
