defmodule RetWeb.Schema do
  use Absinthe.Schema

  import_types(Absinthe.Type.Custom)
  import_types(RetWeb.Schema.RoomTypes)

  query do
    import_fields(:room_queries)
  end

  mutation do
    import_fields(:room_mutations)
  end
end