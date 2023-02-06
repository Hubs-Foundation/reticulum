defmodule Ret.BitFieldUtils do
  import Bitwise

  def permissions_to_map(nil = _bit_field, permissions) do
    0 |> permissions_to_map(permissions)
  end

  # Convert a permissions bit field integer into a {:permission_name => boolean} map
  def permissions_to_map(bit_field, permissions) do
    num_permissions = (permissions |> Enum.count()) - 1

    0..num_permissions
    |> Enum.map(&bsl(1, &1))
    |> Enum.map(&{permissions[&1], (bit_field &&& &1) == &1})
    |> Map.new()
  end
end
