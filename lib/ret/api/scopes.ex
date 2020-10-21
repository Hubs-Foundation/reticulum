defmodule Ret.Api.Scopes do
  @moduledoc false
  def read_rooms, do: Atom.to_string(:read_rooms)
  def write_rooms, do: Atom.to_string(:write_rooms)
  def create_accounts, do: Atom.to_string(:create_accounts)
end
