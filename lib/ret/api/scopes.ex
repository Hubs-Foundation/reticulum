defmodule Ret.Api.Scopes do
  @moduledoc false
  def read_rooms, do: Atom.to_string(:read_rooms)
  def write_rooms, do: Atom.to_string(:write_rooms)
  def create_accounts, do: Atom.to_string(:create_accounts)

  def ensure_has_scope(scopes, scope) do
    if scope in scopes do
      :ok
    else
      {:error, "Missing scope #{Atom.to_string(scope)}"}
    end
  end
end
