defmodule RetWeb.Schema do
  @moduledoc false

  use Absinthe.Schema
  alias Ret.{Scene, ApiPermissions}

  alias RetWeb.Middlewares.{VerifyScopes, HandleChangesetErrors, StartTiming, EndTiming, InspectTiming}

  def middleware(middleware, field, object) do
    middleware = maybe_verify_scopes(middleware, field, object)
    middleware = maybe_add_handle_changeset_errors(middleware, field, object)
    middleware = maybe_add_timing(middleware, field, object)
  end

  @auth_fields [
    :my_rooms,
    :public_rooms,
    :favorite_rooms,
    :create_room,
    :update_room
  ]

  defp maybe_verify_scopes(middleware, %{identifier: identifier}, _object) when identifier in @auth_fields do
    [VerifyScopes] ++ middleware
  end
  defp maybe_verify_scopes(middleware, _field, _object) do
    middleware
  end

  defp maybe_add_handle_changeset_errors(middleware, _field, %{identifier: :mutation}) do
    middleware ++ [HandleChangesetErrors]
  end

  defp maybe_add_handle_changeset_errors(middleware, _field, _object) do
    middleware
  end

  @timing_ids [
    :my_rooms,
    :public_rooms,
    :favorite_rooms,
    :create_room,
    :update_room
  ]

  defp maybe_add_timing(middleware, %{identifier: identifier}, _object) when identifier in @timing_ids do
    [StartTiming] ++ middleware ++ [EndTiming, InspectTiming]
  end

  defp maybe_add_timing(middleware, _field, _object) do
    middleware
  end

  import_types(Absinthe.Type.Custom)
  import_types(RetWeb.Schema.RoomTypes)
  import_types(RetWeb.Schema.SceneTypes)

  query do
    import_fields(:room_queries)
  end

  mutation do
    import_fields(:room_mutations)
  end

  def context(ctx) do
    loader =
      Dataloader.new()
      |> Dataloader.add_source(Scene, Scene.data())

    Map.put(ctx, :loader, loader)
  end

  def plugins do
    [Absinthe.Middleware.Dataloader] ++ Absinthe.Plugin.defaults()
  end
end
