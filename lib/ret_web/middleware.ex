defmodule RetWeb.Middleware do
  @moduledoc "Adds absinthe middleware on matching fields/objects"

  alias RetWeb.Middleware.{
    HandleApiTokenAuthErrors,
    HandleChangesetErrors,
    StartTiming,
    EndTiming,
    InspectTiming
  }

  @timing_ids [
    :my_rooms,
    :public_rooms,
    :favorite_rooms,
    :create_room,
    :update_room
  ]

  def build_middleware(middleware, %{identifier: field_id} = _field, _object) do
    include_timing = field_id in @timing_ids

    if(include_timing, do: [StartTiming], else: []) ++
      [HandleApiTokenAuthErrors] ++
      middleware ++
      [HandleChangesetErrors] ++
      if(include_timing, do: [EndTiming], else: []) ++
      if(include_timing, do: [InspectTiming], else: [])
  end
end
