defmodule RetWeb.Schema do
  use Absinthe.Schema
  alias Ret.Scene

  def middleware(middleware, _field, %{identifier: :mutation}) do
    middleware ++ [RetWeb.Middlewares.HandleChangesetErrors]
  end
  def middleware(middleware, _field, _object), do: middleware

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
      Dataloader.new
      |> Dataloader.add_source(Scene, Scene.data())
  
    Map.put(ctx, :loader, loader)
  end
  
  def plugins do
    [Absinthe.Middleware.Dataloader] ++ Absinthe.Plugin.defaults()
  end
  
end
