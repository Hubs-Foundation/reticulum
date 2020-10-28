defmodule Ret.Api.Scopes do
  @moduledoc false
  def read_rooms, do: :read_rooms
  def write_rooms, do: :write_rooms
  def create_accounts, do: :create_accounts

  def all_scopes,
    do: [
      read_rooms(),
      write_rooms(),
      create_accounts()
    ]
end
