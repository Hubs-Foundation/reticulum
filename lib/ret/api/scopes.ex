defmodule Ret.Api.Scopes do
  @moduledoc false
  def read_rooms, do: :read_rooms
  def write_rooms, do: :write_rooms

  def all_scopes,
    do: [
      read_rooms(),
      write_rooms()
    ]
end
