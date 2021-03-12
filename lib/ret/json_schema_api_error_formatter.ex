defmodule Ret.JsonSchemaApiErrorFormatter do
  @moduledoc false
  def format(errors) do
    ExJsonSchema.Validator.Error.StringFormatter.format(errors)
    |> Enum.map(&{:MALFORMED_RECORD, elem(&1, 0), elem(&1, 1)})
  end
end
