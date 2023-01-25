defmodule RetWeb.Schema do
  @moduledoc false

  use Absinthe.Schema

  import RetWeb.Middleware, only: [build_middleware: 3]

  def middleware(middleware, field, object) do
    build_middleware(middleware, field, object)
  end

  import_types Absinthe.Type.Custom
  import_types RetWeb.Schema.RoomTypes
  import_types RetWeb.Schema.SceneTypes

  query do
    import_fields :room_queries
  end

  mutation do
    import_fields :room_mutations
  end

  def context(ctx) do
    loader =
      Dataloader.new()
      |> Dataloader.add_source(:db, Ret.Api.Dataloader.source())

    Map.put(ctx, :loader, loader)
  end

  def plugins do
    [Absinthe.Middleware.Dataloader] ++ Absinthe.Plugin.defaults()
  end
end
