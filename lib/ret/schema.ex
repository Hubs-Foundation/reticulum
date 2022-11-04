defmodule Ret.Schema do
  @moduledoc """
  Conveniences for working with Ecto schemas.
  """

  @spec is_struct(term) :: boolean
  defguardp is_struct(term)
            when is_map(term) and :erlang.is_map_key(:__struct__, term) and is_atom(:erlang.map_get(:__struct__, term))

  @spec is_struct(term, module) :: boolean
  defguardp is_struct(term, module)
            when is_map(term) and
                   is_atom(module) and
                   :erlang.is_map_key(:__struct__, term) and
                   :erlang.map_get(:__struct__, term) === module

  @doc """
  Determines if a `term` is an Ecto schema.

  Returns `true` if the given `term` is an Ecto schema, otherwise it returns
  `false`.

  Allowed in guard clauses.

  ## Examples

      iex> Schema.is_schema(%Account{})
      true

      iex> Schema.is_schema(%Date{})
      false

      iex> Schema.is_schema(123)
      false

  """
  @spec is_schema(term) :: boolean
  defguard is_schema(term)
           when is_struct(term) and
                  :erlang.is_map_key(:__meta__, term) and
                  is_struct(:erlang.map_get(:__meta__, term), Ecto.Schema.Metadata)

  @doc """
  Determines if a `term` is a serial ID.

  Returns `true` if the given `term` is a serial ID, otherwise it returns
  `false`.

  Allowed in guard clauses.

  ## Examples

      iex> Schema.is_serial_id(10)
      true

      iex> Schema.is_serial_id("7ebc6052-5256-402b-8a8b-b33a5727068b")
      false

      iex> Schema.is_serial_id(0)
      false

  """
  @spec is_serial_id(term) :: boolean
  defguard is_serial_id(term) when is_integer(term) and term > 0
end
