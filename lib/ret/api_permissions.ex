defmodule Ret.ApiPermissions do
  @moduledoc """
  Helper module for defining permissions and scopes
  """

  def perms_for_account() do
    perms_for_scopes([scope_default(), scope_rooms_user()])
  end

  def default_permissions() do
    perms_for_scopes([scope_default()])
  end

  defp permissions do
    [
      :rooms_mutation_create_room,
      :rooms_mutation_update_room,
      :rooms_query_created_rooms,
      :rooms_query_favorite_rooms,
      :rooms_query_public_rooms
    ]
  end

  defp scope_default do
    [
      :rooms_mutation_create_room,
      :rooms_query_public_rooms
    ]
  end

  defp scope_rooms_user do
    [
      :rooms_mutation_create_room,
      :rooms_mutation_update_room,
      :rooms_query_created_rooms,
      :rooms_query_favorite_rooms
    ]
  end

  defp perms_for_scopes(scopes) when is_list(scopes) do
    no_permissions = Map.new(permissions(), fn perm -> {perm, false} end)

    Enum.reduce(Enum.concat(scopes), no_permissions, fn perm, acc ->
      Map.put(acc, perm, true)
    end)
  end
end
