defmodule RetWeb.Schema do
  use Absinthe.Schema

  def middleware(middleware, _field, %{identifier: :mutation}) do
    middleware ++ [RetWeb.Middlewares.HandleChangesetErrors]
  end
  def middleware(middleware, _field, _object), do: middleware

  import_types(Absinthe.Type.Custom)
  import_types(RetWeb.Schema.RoomTypes)

  query do
    import_fields(:room_queries)
  end

  mutation do
    import_fields(:room_mutations)
  end
end
