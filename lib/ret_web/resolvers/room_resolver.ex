defmodule RetWeb.Resolvers.RoomResolver do
  alias Ret.Hub

  def list_rooms(_parent, _args, _resolutions) do
    {:ok, IO.inspect(Hub.get_public_rooms(0, 10))}
  end

  def create_room(_parent, args, _resolutions) do
    args
    |> Hub.create()
    |> case do
      {:ok, room} ->
        {:ok, room}

      {:error, changeset} ->
        {:error, extract_error_message(changeset)}
    end
  end

  defp extract_error_message(changeset) do
    Enum.map(changeset.errors, fn {field, {error, _details}} ->
      [
        field: field,
        message: String.capitalize(error)
      ]
    end)
  end
end